//
//  AppSettings.swift
//  SiteSurvey
//
//  アプリ設定モデル（デフォルト表示スコープなど）
//

import Foundation
import SwiftData

/// アプリ全体設定（SwiftDataで1レコード管理）
@Model
final class AppSettings {
    var id: UUID = UUID()
    /// デフォルト表示スコープ
    /// "all" / "untagged" / "archived" / "tag:<UUIDString>"
    var defaultScopeRaw: String = "all"

    init() {}

    static let defaultScopeAll = "all"
    static let defaultScopeUntagged = "untagged"
    static let defaultScopeArchived = "archived"
    static func tagScope(_ id: UUID) -> String { "tag:\(id.uuidString)" }
}
