//
//  ImageStorage.swift
//  SiteSurvey
//
//  画像保存・読み込み・合成
//

import UIKit
import PencilKit

// @MainActorを削除してwatchdogタイムアウトを防止
class ImageStorage {
    static let shared = ImageStorage()
    
    // 通知名
    static let thumbUpdatedNotification = Notification.Name("ImageStorage.thumbUpdated")
    
    // キャッシュ（スレッドセーフ）
    private let thumbCache = NSCache<NSString, UIImage>()
    private let compositeCache = NSCache<NSString, UIImage>()
    
    // 設定値
    private let maxImageSize: CGFloat = 1200
    private let imageCompressionQuality: CGFloat = 0.7
    private let thumbMaxSize: CGFloat = 150
    private let thumbCompressionQuality: CGFloat = 0.6
    
    private init() {
        thumbCache.countLimit = 30
        compositeCache.countLimit = 10
        createDirectoriesIfNeeded()
    }
    
    // MARK: - ディレクトリ
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var imagesDirectory: URL {
        documentsDirectory.appendingPathComponent("Imgs", isDirectory: true)
    }
    
    private var thumbsDirectory: URL {
        documentsDirectory.appendingPathComponent("Thumbs", isDirectory: true)
    }
    
    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - 保存
    
    func saveImage(_ image: UIImage) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        
        // リサイズ
        let resized = resizeImage(image, maxSize: maxImageSize)
        
        // JPEG形式で保存（HEICではない）
        guard let data = resized.jpegData(compressionQuality: imageCompressionQuality) else { return nil }
        
        let imageURL = imagesDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: imageURL)
        } catch {
            print("画像保存エラー: \(error)")
            return nil
        }
        
        // サムネイル生成
        let thumb = resizeImage(image, maxSize: thumbMaxSize)
        if let thumbData = thumb.jpegData(compressionQuality: thumbCompressionQuality) {
            let thumbURL = thumbsDirectory.appendingPathComponent(fileName)
            try? thumbData.write(to: thumbURL)
        }
        
        return fileName
    }
    
    // MARK: - 読み込み
    
    func loadImage(_ fileName: String) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    func loadThumb(_ fileName: String) -> UIImage? {
        // キャッシュ確認
        if let cached = thumbCache.object(forKey: fileName as NSString) {
            return cached
        }
        
        let url = thumbsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        
        thumbCache.setObject(image, forKey: fileName as NSString)
        return image
    }
    
    // MARK: - 削除
    
    func deleteImage(_ fileName: String) {
        let imageURL = imagesDirectory.appendingPathComponent(fileName)
        let thumbURL = thumbsDirectory.appendingPathComponent(fileName)
        
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: thumbURL)
        
        thumbCache.removeObject(forKey: fileName as NSString)
        compositeCache.removeObject(forKey: fileName as NSString)
    }
    
    // MARK: - 画像回転
    
    func rotateImage(_ fileName: String) async -> Bool {
        // 必要な値をローカルにコピー
        let imagesDir = imagesDirectory
        let thumbsDir = thumbsDirectory
        let compressionQuality = imageCompressionQuality
        let thumbMaxSz = thumbMaxSize
        let thumbCompression = thumbCompressionQuality
        
        guard let image = loadImage(fileName) else { return false }
        
        let success = await Task.detached {
            let rotated = Self.rotate90Degrees(image)
            
            // 元画像を上書き保存
            guard let data = rotated.jpegData(compressionQuality: compressionQuality) else { return false }
            let imageURL = imagesDir.appendingPathComponent(fileName)
            do {
                try data.write(to: imageURL)
            } catch {
                return false
            }
            
            // サムネイル更新
            let thumb = Self.resizeImageStatic(rotated, maxSize: thumbMaxSz)
            if let thumbData = thumb.jpegData(compressionQuality: thumbCompression) {
                let thumbURL = thumbsDir.appendingPathComponent(fileName)
                try? thumbData.write(to: thumbURL)
            }
            
            return true
        }.value
        
        if success {
            // キャッシュクリア
            thumbCache.removeObject(forKey: fileName as NSString)
            compositeCache.removeObject(forKey: fileName as NSString)
        }
        
        return success
    }
    
    nonisolated private static func rotate90Degrees(_ image: UIImage) -> UIImage {
        let newSize = CGSize(width: image.size.height, height: image.size.width)
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: .pi / 2)
        context.translateBy(x: -image.size.width / 2, y: -image.size.height / 2)
        
        image.draw(at: .zero)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    // MARK: - サムネイル更新（同期）
    
    func updateThumbSync(_ fileName: String, drawing: PKDrawing?, textOverlay: UIImage? = nil) {
        guard let image = loadImage(fileName) else { return }
        
        // 合成画像作成
        let composite = doComposite(image: image, drawing: drawing, textOverlay: textOverlay)
        
        // サムネイルサイズにリサイズ
        let thumb = resizeImage(composite, maxSize: thumbMaxSize)
        
        // 保存
        if let thumbData = thumb.jpegData(compressionQuality: thumbCompressionQuality) {
            let thumbURL = thumbsDirectory.appendingPathComponent(fileName)
            try? thumbData.write(to: thumbURL)
        }
        
        // キャッシュ更新
        thumbCache.setObject(thumb, forKey: fileName as NSString)
        compositeCache.removeObject(forKey: fileName as NSString)
        
        // 通知
        NotificationCenter.default.post(name: Self.thumbUpdatedNotification, object: fileName)
    }
    
    // MARK: - 画像合成
    
    func getCompositeImage(_ fileName: String, drawing: PKDrawing?, textOverlay: UIImage? = nil) -> UIImage? {
        // 描画データがない場合は元画像を返す
        let hasMarkup = (drawing != nil && !drawing!.strokes.isEmpty) || textOverlay != nil
        if !hasMarkup {
            return loadImage(fileName)
        }
        
        // キャッシュ確認は行わない（常に最新を生成）
        guard let image = loadImage(fileName) else { return nil }
        
        let composite = doComposite(image: image, drawing: drawing, textOverlay: textOverlay)
        compositeCache.setObject(composite, forKey: fileName as NSString)
        
        return composite
    }
    
    func doComposite(image: UIImage, drawing: PKDrawing?, textOverlay: UIImage? = nil) -> UIImage {
        let imageSize = image.size
        
        // 重要: 第2引数を false にして透明背景をサポート（PKDrawingの透明部分を維持）
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // 1. 元画像を描画
        image.draw(at: .zero)
        
        // 2. PKDrawing を重ねる
        if let drawing = drawing, !drawing.strokes.isEmpty {
            // 画像全体サイズに合わせたImageを取得
            let drawingImage = drawing.image(from: CGRect(origin: .zero, size: imageSize), scale: 1.0)
            drawingImage.draw(at: .zero)
        }
        
        // 3. テキストオーバーレイを重ねる
        if let textOverlay = textOverlay {
            // テキストオーバーレイを画像サイズに合わせてリサイズして描画
            textOverlay.draw(in: CGRect(origin: .zero, size: imageSize))
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    // MARK: - リサイズ
    
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        Self.resizeImageStatic(image, maxSize: maxSize)
    }
    
    nonisolated private static func resizeImageStatic(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        
        if ratio >= 1 { return image }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    // MARK: - PDF用画像取得（高画質版: 400pxにリサイズ）
    
    func getImageForPDF(_ fileName: String, drawing: PKDrawing?, textOverlay: UIImage? = nil) -> UIImage? {
        guard let composite = getCompositeImage(fileName, drawing: drawing, textOverlay: textOverlay) else {
            return nil
        }
        return resizeImage(composite, maxSize: 800)
    }
}
