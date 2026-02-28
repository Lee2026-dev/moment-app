//
//  ThemeManager.swift
//  moment
//

import SwiftUI
import Combine
import UIKit

protocol Theme {
    var primary: Color { get }
    var secondary: Color { get }
    var accent: Color { get }
    var background: Color { get }
    var surface: Color { get }
    var surfaceElevated: Color { get }
    var text: Color { get }
    var textSecondary: Color { get }
    var recording: Color { get }
    var success: Color { get }
    var warning: Color { get }
    var destructive: Color { get }
    var border: Color { get }
    var shadow: Color { get }
    
    // UIKit compatibility
    var textUIColor: UIColor { get }
    var textSecondaryUIColor: UIColor { get }
}

enum ThemeOption: String, CaseIterable, Identifiable {
    case system = "system"
    case classic = "classic"
    case midnightGold = "midnight_gold"
    case deepOcean = "deep_ocean"
    case emeraldForest = "emerald_forest"
    case royalPurple = "royal_purple"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .classic: return "经典时刻"
        case .midnightGold: return "午夜金"
        case .deepOcean: return "深海"
        case .emeraldForest: return "翡翠森林"
        case .royalPurple: return "皇家紫"
        }
    }
}

// MARK: - Theme Implementations

struct SystemTheme: Theme {
    var primary: Color { Color.dynamic(light: "0F172A", dark: "F8FAFC") }
    var secondary: Color { Color.dynamic(light: "334155", dark: "94A3B8") }
    var accent: Color { Color(hex: "6366F1") }
    var background: Color { Color.dynamic(light: "F5F5F7", dark: "000000") }
    var surface: Color { Color.dynamic(light: "FFFFFF", dark: "1C1C1E") }
    var surfaceElevated: Color { Color.dynamic(light: "FFFFFF", dark: "2C2C2E") }
    var text: Color { Color.dynamic(light: "0F172A", dark: "F8FAFC") }
    var textSecondary: Color { Color.dynamic(light: "64748B", dark: "94A3B8") }
    var recording: Color { Color(hex: "E11D48") }
    var success: Color { Color(hex: "10B981") }
    var warning: Color { Color(hex: "F59E0B") }
    var destructive: Color { Color(hex: "E11D48") }
    var border: Color { Color.dynamic(light: "E2E8F0", dark: "2C2C2E") }
    var shadow: Color { Color.black.opacity(0.08) }
    
    var textUIColor: UIColor { Color.dynamicUIColor(light: "0F172A", dark: "F8FAFC") }
    var textSecondaryUIColor: UIColor { Color.dynamicUIColor(light: "64748B", dark: "94A3B8") }
}

struct ClassicTheme: Theme {
    var primary: Color { Color(hex: "0F172A") }
    var secondary: Color { Color(hex: "334155") }
    var accent: Color { Color(hex: "6366F1") }
    var background: Color { Color(hex: "F5F5F7") }
    var surface: Color { Color(hex: "FFFFFF") }
    var surfaceElevated: Color { Color(hex: "FFFFFF") }
    var text: Color { Color(hex: "0F172A") }
    var textSecondary: Color { Color(hex: "64748B") }
    var recording: Color { Color(hex: "E11D48") }
    var success: Color { Color(hex: "10B981") }
    var warning: Color { Color(hex: "F59E0B") }
    var destructive: Color { Color(hex: "E11D48") }
    var border: Color { Color(hex: "E2E8F0") }
    var shadow: Color { Color.black.opacity(0.08) }
    
    var textUIColor: UIColor { UIColor(Color(hex: "0F172A")) }
    var textSecondaryUIColor: UIColor { UIColor(Color(hex: "64748B")) }
}

struct MidnightGoldTheme: Theme {
    var primary: Color { Color(hex: "F8FAFC") }
    var secondary: Color { Color(hex: "94A3B8") }
    var accent: Color { Color(hex: "F7E7CE") } // Champagne Gold
    var background: Color { Color(hex: "000000") }
    var surface: Color { Color(hex: "1C1C1E") }
    var surfaceElevated: Color { Color(hex: "2C2C2E") }
    var text: Color { Color(hex: "F8FAFC") }
    var textSecondary: Color { Color(hex: "94A3B8") }
    var recording: Color { Color(hex: "FF453A") }
    var success: Color { Color(hex: "32D74B") }
    var warning: Color { Color(hex: "FFD60A") }
    var destructive: Color { Color(hex: "FF453A") }
    var border: Color { Color(hex: "38383A") }
    var shadow: Color { Color.white.opacity(0.05) }
    
    var textUIColor: UIColor { UIColor(Color(hex: "F8FAFC")) }
    var textSecondaryUIColor: UIColor { UIColor(Color(hex: "94A3B8")) }
}

struct DeepOceanTheme: Theme {
    var primary: Color { Color(hex: "F0F9FF") }
    var secondary: Color { Color(hex: "7DD3FC") }
    var accent: Color { Color(hex: "0EA5E9") } // Cyan
    var background: Color { Color(hex: "082F49") }
    var surface: Color { Color(hex: "0C4A6E") }
    var surfaceElevated: Color { Color(hex: "075985") }
    var text: Color { Color(hex: "F0F9FF") }
    var textSecondary: Color { Color(hex: "BAE6FD") }
    var recording: Color { Color(hex: "FB7185") }
    var success: Color { Color(hex: "34D399") }
    var warning: Color { Color(hex: "FBBF24") }
    var destructive: Color { Color(hex: "FB7185") }
    var border: Color { Color(hex: "0EA5E9").opacity(0.2) }
    var shadow: Color { Color.black.opacity(0.2) }
    
    var textUIColor: UIColor { UIColor(Color(hex: "F0F9FF")) }
    var textSecondaryUIColor: UIColor { UIColor(Color(hex: "BAE6FD")) }
}

struct EmeraldForestTheme: Theme {
    var primary: Color { Color(hex: "F0FDF4") }
    var secondary: Color { Color(hex: "86EFAC") }
    var accent: Color { Color(hex: "10B981") } // Emerald
    var background: Color { Color(hex: "064E3B") }
    var surface: Color { Color(hex: "065F46") }
    var surfaceElevated: Color { Color(hex: "047857") }
    var text: Color { Color(hex: "F0FDF4") }
    var textSecondary: Color { Color(hex: "BBF7D0") }
    var recording: Color { Color(hex: "F43F5E") }
    var success: Color { Color(hex: "34D399") }
    var warning: Color { Color(hex: "F59E0B") }
    var destructive: Color { Color(hex: "F43F5E") }
    var border: Color { Color(hex: "10B981").opacity(0.2) }
    var shadow: Color { Color.black.opacity(0.2) }
    
    var textUIColor: UIColor { UIColor(Color(hex: "F0FDF4")) }
    var textSecondaryUIColor: UIColor { UIColor(Color(hex: "BBF7D0")) }
}

struct RoyalPurpleTheme: Theme {
    var primary: Color { Color(hex: "FAF5FF") }
    var secondary: Color { Color(hex: "D8B4FE") }
    var accent: Color { Color(hex: "8B5CF6") } // Violet
    var background: Color { Color(hex: "2E1065") }
    var surface: Color { Color(hex: "4C1D95") }
    var surfaceElevated: Color { Color(hex: "5B21B6") }
    var text: Color { Color(hex: "FAF5FF") }
    var textSecondary: Color { Color(hex: "E9D5FF") }
    var recording: Color { Color(hex: "F43F5E") }
    var success: Color { Color(hex: "34D399") }
    var warning: Color { Color(hex: "F59E0B") }
    var destructive: Color { Color(hex: "F43F5E") }
    var border: Color { Color(hex: "8B5CF6").opacity(0.2) }
    var shadow: Color { Color.black.opacity(0.2) }
    
    var textUIColor: UIColor { UIColor(Color(hex: "FAF5FF")) }
    var textSecondaryUIColor: UIColor { UIColor(Color(hex: "E9D5FF")) }
}

// MARK: - ThemeManager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private let selectedThemeKey = "selected_theme"

    @Published var selectedTheme: ThemeOption {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: selectedThemeKey)
        }
    }

    private init() {
        let storedThemeRawValue = UserDefaults.standard.string(forKey: selectedThemeKey) ?? ThemeOption.system.rawValue
        selectedTheme = ThemeOption(rawValue: storedThemeRawValue) ?? .system
    }
    
    var activeTheme: Theme {
        switch selectedTheme {
        case .system: return SystemTheme()
        case .classic: return ClassicTheme()
        case .midnightGold: return MidnightGoldTheme()
        case .deepOcean: return DeepOceanTheme()
        case .emeraldForest: return EmeraldForestTheme()
        case .royalPurple: return RoyalPurpleTheme()
        }
    }
    
    var preferredColorScheme: ColorScheme? {
        switch selectedTheme {
        case .system: return nil
        case .midnightGold, .deepOcean, .emeraldForest, .royalPurple: return .dark
        case .classic: return .light
        }
    }
}
