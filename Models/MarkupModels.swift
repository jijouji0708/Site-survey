import UIKit
import Foundation

// MARK: - Data Models

struct MarkupData: Codable {
    var texts: [TextAnnotationModel] = []
    var arrows: [ArrowAnnotationModel] = []
    var shapes: [ShapeAnnotationModel] = []
}

struct ShapeAnnotationModel: Codable, Identifiable {
    var id: UUID = UUID()
    var type: String // "rect" or "circle"
    
    // Normalized Coordinates (0.0 - 1.0 relative to Image)
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    
    var colorHex: String
    var lineWidth: CGFloat
    
    var uicolor: UIColor {
        return UIColor(hex: colorHex) ?? .red
    }
}

struct TextAnnotationModel: Codable, Identifiable {
    var id: UUID = UUID()
    var text: String
    var fontSize: CGFloat
    
    // Normalized Coordinates (0.0 - 1.0 relative to Image)
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    
    var colorHex: String
    
    var uicolor: UIColor {
        return UIColor(hex: colorHex) ?? .black
    }
}

struct ArrowAnnotationModel: Codable, Identifiable {
    var id: UUID = UUID()
    
    // Normalized Coordinates (0.0 - 1.0 relative to Image)
    var startX: CGFloat
    var startY: CGFloat
    var endX: CGFloat
    var endY: CGFloat
    
    var colorHex: String
    var lineWidth: CGFloat
    
    var uicolor: UIColor {
        return UIColor(hex: colorHex) ?? .red
    }
}

// MARK: - Color Extension

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        let r, g, b, a: CGFloat
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
    
    func toHex() -> String {
        guard let components = cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = components.count >= 4 ? Float(components[3]) : 1.0
        
        if a != 1.0 {
            return String(format: "#%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}

// MARK: - Benchmark Colors
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
