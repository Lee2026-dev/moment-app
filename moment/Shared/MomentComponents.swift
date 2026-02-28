//
//  MomentComponents.swift
//  moment
//

import SwiftUI

struct MomentCard<Content: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let content: Content
    var padding: CGFloat = 16
    
    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(MomentDesign.Colors.surface)
            .cornerRadius(24)
            .shadow(color: MomentDesign.Colors.shadow.opacity(0.04), radius: 10, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(MomentDesign.Colors.border.opacity(0.8), lineWidth: 0.5)
            )
    }
}

struct MomentButton: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    enum Style {
        case primary
        case secondary
        case outline
        case destructive
    }
    
    let title: String
    let style: Style
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(borderColor, lineWidth: style == .outline ? 1 : 0)
                )
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return MomentDesign.Colors.accent
        case .secondary: return MomentDesign.Colors.secondary.opacity(0.12)
        case .outline: return Color.clear
        case .destructive: return MomentDesign.Colors.destructive
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary: return MomentDesign.Colors.primary
        case .outline: return MomentDesign.Colors.primary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .outline: return MomentDesign.Colors.border
        default: return Color.clear
        }
    }
}

struct MomentSearchField: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var text: String
    var placeholder: String = "Search..."
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(MomentDesign.Colors.textSecondary)
                .font(.system(size: 20, weight: .medium))
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(MomentDesign.Colors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(MomentDesign.Colors.surfaceElevated)
        .cornerRadius(14)
        .shadow(color: MomentDesign.Colors.shadow.opacity(0.05), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(MomentDesign.Colors.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}
