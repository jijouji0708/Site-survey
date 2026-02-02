//
//  Case.swift
//  SiteSurvey
//
//  案件モデル
//

import Foundation
import SwiftData

@Model
final class Case {
    var id: UUID = UUID()
    var title: String = ""
    var overallNote: String = ""
    var address: String = ""
    var area: String = "" // エリア（自由入力）
    var showCoverPage: Bool = true // 表紙（メモ・詳細）を表示するかどうか
    
    // 詳細情報
    // 曜日: 1=Sun, ..., 7=Sat (Calendar.current.component(.weekday, ...)準拠)
    // デフォルト: 日(1), 土(7) を選択状態
    var workWeekdays: [Int] = [1, 7]
    
    // デフォルト: 9:00 (未定の場合は nil)
    var workStartTime: Date? = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))
    
    // デフォルト: 17:00 (未定の場合は nil)
    var workEndTime: Date? = Calendar.current.date(from: DateComponents(hour: 17, minute: 0))
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    @Relationship(deleteRule: .cascade)
    var photos: [CasePhoto] = []
    
    // キャッシュ付きソート済み写真
    @Transient private var _sortedPhotos: [CasePhoto]?
    var sortedPhotos: [CasePhoto] {
        if _sortedPhotos == nil {
            _sortedPhotos = photos.sorted { $0.orderIndex < $1.orderIndex }
        }
        return _sortedPhotos ?? []
    }
    
    func invalidateSortCache() {
        _sortedPhotos = nil
    }
    
    func touch() {
        updatedAt = Date()
        invalidateSortCache()
    }
    
    func normalizePhotoOrder() {
        for (i, p) in sortedPhotos.enumerated() {
            p.orderIndex = i
        }
        invalidateSortCache()
    }
    
    init() {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        self.title = "\(df.string(from: Date())) 現場調査"
    }
}
