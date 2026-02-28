//
//  Tag.swift
//  SiteSurvey
//
//  タグモデル
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#4A90E2"
    var createdAt: Date = Date()
    var sortOrder: Double = Date().timeIntervalSince1970

    @Relationship(inverse: \Case.tags)
    var cases: [Case] = []

    init(name: String, colorHex: String = "#4A90E2") {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.sortOrder = Date().timeIntervalSince1970
    }

    /// SwiftUIのColorに変換
    var color: Color {
        Color(hex: colorHex) ?? Color.blue
    }
}

// MARK: - Color hex helper
extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#4A90E2"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
