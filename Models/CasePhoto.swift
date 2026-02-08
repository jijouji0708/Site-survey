//
//  CasePhoto.swift
//  SiteSurvey
//
//  写真モデル + アノテーション + UIColor拡張
//

import Foundation
import SwiftData
import PencilKit
import UIKit

// MARK: - CasePhoto モデル
@Model
final class CasePhoto {
    var id: UUID = UUID()
    var imageFileName: String
    var orderIndex: Int
    var note: String = ""
    var createdAt: Date = Date()
    
    var markupData: Data?
    
    // アノテーションデータ（JSON形式、テキスト・矢印のオブジェクトデータ）
    var annotationData: Data?
    
    // 後方互換性のため残すが、基本は使用しない（またはサムネイル生成用に使用）
    var textOverlayData: Data?
    
    // 結合写真フラグ
    var isComposite: Bool = false
    
    // 結合元の画像ファイル名（解除時に復元用）
    var sourceImageFileNames: [String]? = nil
    
    // 1ページ表示フラグ（PDFで1枚1ページで表示）
    var isFullPage: Bool = false
    
    var parentCase: Case?
    
    // PKDrawing アクセサ
    var drawing: PKDrawing? {
        guard let data = markupData else { return nil }
        return try? PKDrawing(data: data)
    }
    
    func setDrawing(_ d: PKDrawing) {
        markupData = d.dataRepresentation()
    }
    
    // アノテーションオブジェクトアクセサ
    var annotations: MarkupData? {
        get {
            guard let data = annotationData else { return nil }
            return try? JSONDecoder().decode(MarkupData.self, from: data)
        }
        set {
            if let newValue = newValue {
                annotationData = try? JSONEncoder().encode(newValue)
            } else {
                annotationData = nil
            }
        }
    }
    
    // テキストオーバーレイ画像アクセサ（旧来の互換性用、または表示用）
    var textOverlay: UIImage? {
        guard let data = textOverlayData else { return nil }
        return UIImage(data: data)
    }
    
    func setTextOverlay(_ image: UIImage?) {
        textOverlayData = image?.pngData()
    }
    
    /// マークアップを90度右回転（画像回転時に呼び出す）
    /// - Parameter originalImageSize: 回転前の画像サイズ
    func rotateMarkup90Clockwise(originalImageSize: CGSize) {
        // 1. PKDrawingの回転
        if let drawing = drawing {
            let rotatedDrawing = rotateDrawing90Clockwise(drawing, originalImageSize: originalImageSize)
            setDrawing(rotatedDrawing)
        }
        
        // 2. アノテーションの回転
        if let annotations = annotations {
            self.annotations = annotations.rotated90Clockwise()
        }
        
        // 3. テキストオーバーレイは再生成が必要なためクリア
        // （アノテーション情報から再描画されるため）
        textOverlayData = nil
    }
    
    /// PKDrawingを90度右回転
    private func rotateDrawing90Clockwise(_ drawing: PKDrawing, originalImageSize: CGSize) -> PKDrawing {
        let width = originalImageSize.width
        let height = originalImageSize.height
        
        // 回転後のサイズ
        let newSize = CGSize(width: height, height: width)
        
        // 90度右回転のアフィン変換を作成
        // 1. 原点を中心に移動
        // 2. 90度回転
        // 3. 新しいサイズに合わせて位置調整
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: newSize.width / 2, y: newSize.height / 2)
        transform = transform.rotated(by: .pi / 2)
        transform = transform.translatedBy(x: -width / 2, y: -height / 2)
        
        return drawing.transformed(using: transform)
    }
    
    init(imageFileName: String, orderIndex: Int) {
        self.imageFileName = imageFileName
        self.orderIndex = orderIndex
    }
}
