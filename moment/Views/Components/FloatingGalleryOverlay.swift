//
//  FloatingGalleryOverlay.swift
//  moment
//
//  Created by Antigravity on 2026/01/26.
//

import SwiftUI

struct FloatingGalleryOverlay: View {
    @Binding var images: [Data]
    @Binding var isExpanded: Bool
    var namespace: Namespace.ID
    var onTapImage: ((Int) -> Void)?
    var onDeleteImage: ((Int) -> Void)?
    
    // Keyboard/Toolbar offset
    var bottomOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Dimmed Background (only when expanded)
            if isExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
                    .zIndex(0)
            }
            
            // Content
            if isExpanded {
                // Expanded Mode: Centered Grid
                VStack(alignment: .trailing) {
                    // Close Button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                        HapticHelper.light()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 20)
                    
                    ScrollView {
                        SmartGalleryView(
                            images: images,
                            onTap: onTapImage,
                            onDelete: onDeleteImage,
                            namespace: namespace
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(1)
            } else if !images.isEmpty {
                // Collapsed Mode: Bottom-Right Corner Bubble
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        PhotoStackView(
                            images: images,
                            namespace: namespace,
                            onTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    isExpanded = true
                                }
                                HapticHelper.light()
                            }
                        )
                        .frame(width: 120, height: 120) // Smaller frame for the bubble
                        .scaleEffect(0.6) // Scale down the stack to make it bubble-like
                        .rotationEffect(.degrees(-5))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .padding(.trailing, 20)
                        .padding(.bottom, bottomOffset + 20) // Adjust for toolbar
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
    }
}
