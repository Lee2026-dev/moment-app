
import SwiftUI

struct ThemeSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            MomentDesign.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Appearance")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(ThemeOption.allCases) { option in
                                ThemeOptionRow(
                                    option: option,
                                    isSelected: themeManager.selectedTheme == option,
                                    isLast: option == ThemeOption.allCases.last
                                ) {
                                    withAnimation {
                                        themeManager.selectedTheme = option
                                        HapticHelper.medium()
                                    }
                                }
                            }
                        }
                        .background(MomentDesign.Colors.surface)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(MomentDesign.Colors.border.opacity(0.5), lineWidth: 0.5)
                        )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Appearance")
    }
}

struct ThemeOptionRow: View {
    let option: ThemeOption
    let isSelected: Bool
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Circle()
                        .fill(themePreviewColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(MomentDesign.Colors.border, lineWidth: 1)
                        )
                    
                    Text(option.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(MomentDesign.Colors.text)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(MomentDesign.Colors.accent)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                if !isLast {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var themePreviewColor: Color {
        switch option {
        case .system: return Color.primary
        case .classic: return Color(hex: "6366F1")
        case .midnightGold: return Color(hex: "F7E7CE")
        case .deepOcean: return Color(hex: "0EA5E9")
        case .emeraldForest: return Color(hex: "10B981")
        case .royalPurple: return Color(hex: "8B5CF6")
        }
    }
}
