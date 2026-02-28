//
//  LaunchScreenView.swift
//  moment
//
//  Created by wen li on 2026/02/15.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            // Background
            MomentDesign.Colors.surface
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Logo & Animation
                ZStack {
                    // Outer glow/pulse
                    Circle()
                        .fill(MomentDesign.Colors.accent.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .scaleEffect(isAnimating ? 1.4 : 1.0)
                        .opacity(isAnimating ? 0.0 : 1.0)
                    
                    // Main Logo Container
                    ZStack {
                        Circle()
                            .fill(MomentDesign.Colors.surfaceElevated)
                            .shadow(color: MomentDesign.Colors.shadow.opacity(0.1), radius: 20, x: 0, y: 10)
                            .frame(width: 120, height: 120)
                        
                        Image("app-icon") // Using the app icon asset
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                }
                
                // App Name
                Text("Moment")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(MomentDesign.Colors.text)
                    .opacity(isAnimating ? 1 : 0.7)
                    .offset(y: isAnimating ? -5 : 5)
                
                // Tagline / Loading Text
                Text("Capture your thoughts")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(MomentDesign.Colors.textSecondary)
                    .opacity(0.8)
                
                Spacer()
                
                // Bottom Indicator (optional, keeps it minimal)
                ProgressView()
                    .tint(MomentDesign.Colors.accent)
                    .scaleEffect(0.8)
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
