//
//  CaseAttachment.swift
//  SiteSurvey
//
//  添付PDFモデル
//

import Foundation
import SwiftData

@Model
final class CaseAttachment {
    var id: UUID = UUID()
    var fileName: String  // Documents/attachments/ 内のファイル名
    var originalName: String  // 元のファイル名（表示用）
    var orderIndex: Int
    var createdAt: Date = Date()
    
    var parentCase: Case?
    
    init(fileName: String, originalName: String, orderIndex: Int) {
        self.fileName = fileName
        self.originalName = originalName
        self.orderIndex = orderIndex
    }
}
