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
    
    init(imageFileName: String, orderIndex: Int) {
        self.imageFileName = imageFileName
        self.orderIndex = orderIndex
    }
}

// MARK: - マークアップカラーパレット（6色）
struct MarkupColors {
    static let white = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let black = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let gray = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
    static let red = UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
    static let blue = UIColor(red: 0, green: 0.48, blue: 1, alpha: 1)
    static let yellow = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
    static let green = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
    
    static let all: [UIColor] = [white, black, gray, red, blue, yellow, green]
}
