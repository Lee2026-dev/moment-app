//
//  MomentDesign.swift
//  moment
//

import SwiftUI
import UIKit

struct MomentDesign {
    struct Colors {
        // Dynamic Palette driven by ThemeManager
        static var primary: Color { ThemeManager.shared.activeTheme.primary }
        static var secondary: Color { ThemeManager.shared.activeTheme.secondary }
        static var accent: Color { ThemeManager.shared.activeTheme.accent }
        
        static var background: Color { ThemeManager.shared.activeTheme.background }
        
        static var surface: Color { ThemeManager.shared.activeTheme.surface }
        static var surfaceElevated: Color { ThemeManager.shared.activeTheme.surfaceElevated }
        
        static var text: Color { ThemeManager.shared.activeTheme.text }
        static var textSecondary: Color { ThemeManager.shared.activeTheme.textSecondary }
        
        static var textUIColor: UIColor { ThemeManager.shared.activeTheme.textUIColor }
        static var textSecondaryUIColor: UIColor { ThemeManager.shared.activeTheme.textSecondaryUIColor }
        
        static var recording: Color { ThemeManager.shared.activeTheme.recording }
        static var success: Color { ThemeManager.shared.activeTheme.success }
        static var warning: Color { ThemeManager.shared.activeTheme.warning }
        static var destructive: Color { ThemeManager.shared.activeTheme.destructive }
        
        static var border: Color { ThemeManager.shared.activeTheme.border }
        static var shadow: Color { ThemeManager.shared.activeTheme.shadow }
    }
    
    struct Typography {
        struct Fonts {
            static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
            static let title = Font.system(size: 22, weight: .bold, design: .rounded)
            static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
            static let body = Font.system(size: 15, weight: .regular, design: .default)
            static let caption = Font.system(size: 12, weight: .medium, design: .default)
        }

        static func largeTitle(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Colors.text)
        }
        
        static func title(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Colors.text)
        }
        
        static func headline(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(Colors.text)
        }
        
        static func body(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(Colors.text)
        }
        
        static func caption(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(Colors.textSecondary)
        }
        
        static func recordingTime(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(Colors.text)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static func dynamic(light: String, dark: String) -> Color {
        return Color(dynamicUIColor(light: light, dark: dark))
    }
    
    static func dynamicUIColor(light: String, dark: String) -> UIColor {
        return UIColor { (traitCollection: UITraitCollection) -> UIColor in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(Color(hex: dark))
            } else {
                return UIColor(Color(hex: light))
            }
        }
    }
}

struct HapticHelper {
    static func light() {
        #if !targetEnvironment(simulator)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    static func medium() {
        #if !targetEnvironment(simulator)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    static func success() {
        #if !targetEnvironment(simulator)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    static func error() {
        #if !targetEnvironment(simulator)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }
}

