//
//  MediaNotePreparerView.swift
//  moment
//

import SwiftUI
import UIKit

struct MediaNotePreparerView: View {
    let images: [Data]
    let onSelectText: () -> Void
    let onSelectAudio: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var animateContent = false
    @State private var selectedImageIndex = 0

    private var firstImage: UIImage? {
        guard let first = images.first else { return nil }
        return UIImage(data: first)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Layer 1: Immersive Background
                backgroundView
                
                // Layer 2: Main Content
                VStack(spacing: 0) {
                    // Header
                    headerView(topInset: proxy.safeAreaInsets.top)
                    
                    Spacer()
                    
                    // Central Card Stack
                    ZStack {
                        if images.isEmpty {
                            emptyStateView
                        } else {
                            cardStackView(geometry: proxy)
                        }
                    }
                    .frame(height: proxy.size.height * 0.55)
                    
                    Spacer()
                    
                    // Bottom Action Bar
                    actionOverlay(bottomInset: proxy.safeAreaInsets.bottom)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animateContent = true
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var backgroundView: some View {
        if let uiImage = firstImage {
            GeometryReader { proxy in
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blur(radius: 80)
                    .overlay(Color.black.opacity(0.6))
                    .transformEffect(.identity) // Optimizes rendering
            }
        } else {
            themeManager.activeTheme.background
        }
    }

    private func headerView(topInset: CGFloat) -> some View {
        HStack {
            Button(action: {
                HapticHelper.light()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("New Moment")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            // Balance the layout
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, max(topInset, 20))
        .padding(.bottom, 10)
    }

    private func cardStackView(geometry: GeometryProxy) -> some View {
        let cardWidth = geometry.size.width * 0.8
        let cardHeight = geometry.size.height * 0.55
        
        return TabView(selection: $selectedImageIndex) {
            ForEach(0..<images.count, id: \.self) { index in
                if let uiImage = UIImage(data: images[index]) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 25, x: 0, y: 15)
                        .rotation3DEffect(
                            .degrees(proxy3DDeformation(geometry: geometry, index: index)),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .tag(index)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never)) // Hide default dots
        .frame(width: geometry.size.width) // Touch area full width
        .overlay(alignment: .bottom) {
            // Refined Page Indicator
            if images.count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<images.count, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(selectedImageIndex == index ? 1 : 0.3))
                            .frame(width: selectedImageIndex == index ? 24 : 6, height: 6)
                            .animation(.spring(), value: selectedImageIndex)
                    }
                }
                .padding(.bottom, -30)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .scaleEffect(animateContent ? 1 : 0.9)
    }
    
    // Calculates simple 3D rotation based on swipe
    private func proxy3DDeformation(geometry: GeometryProxy, index: Int) -> Double {
        // Since we are using standard TabView, we can't easily get scroll offset per frame for all cards
        // without a complex GeometryReader setup inside items.
        // Keeping it simple for stability: static cards or basic transition.
        return 0 
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            Text("No photos selected")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func actionOverlay(bottomInset: CGFloat) -> some View {
        VStack(spacing: 24) {
            // Context Text
            VStack(spacing: 6) {
                Text(animateContent ? "Capture the story" : "")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(animateContent ? "Add your voice or write it down." : "")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            
            // Floating Action Bar
            HStack(spacing: 0) {
                Button(action: onSelectAudio) {
                    VStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(themeManager.activeTheme.accent)
                        Text("Voice")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeManager.activeTheme.text)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                
                // Divider
                Rectangle()
                    .fill(themeManager.activeTheme.border.opacity(0.3))
                    .frame(width: 1, height: 40)
                
                Button(action: onSelectText) {
                    VStack(spacing: 4) {
                        Image(systemName: "text.justify.leading")
                            .font(.system(size: 24))
                            .foregroundColor(themeManager.activeTheme.accent)
                        Text("Text")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeManager.activeTheme.text)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            }
            .background(themeManager.activeTheme.surfaceElevated.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(themeManager.activeTheme.border.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: themeManager.activeTheme.shadow.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
        .padding(.bottom, max(bottomInset, 30))
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 50)
    }
}

// Helper: Press animation
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    MediaNotePreparerView(
        images: [UIImage(systemName: "photo")!.jpegData(compressionQuality: 0.8)!],
        onSelectText: {},
        onSelectAudio: {}
    )
    .environmentObject(ThemeManager.shared)
}
