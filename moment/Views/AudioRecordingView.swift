//  AudioRecordingView.swift
//  moment
//
//  Created by wen li on 2026/1/8.
//

import SwiftUI
import AVFoundation
import Speech
import Combine
import UIKit

struct AudioRecordingView: View {
    @ObservedObject var service = GlobalAudioService.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background
            MomentDesign.Colors.background
                .ignoresSafeArea()
            
            // Soft Animated Background Gradient Mesh
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(MomentDesign.Colors.secondary.opacity(0.15))
                        .frame(width: geometry.size.width * 1.2, height: geometry.size.width * 1.2)
                        .blur(radius: 80)
                        .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.1)
                        .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: service.isRecording)
                    
                    Circle()
                        .fill(MomentDesign.Colors.primary.opacity(0.1))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .blur(radius: 80)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.4)
                        .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: service.isRecording)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top App Bar
                HStack(alignment: .center) {
                    Button(action: {
                        service.minimize()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(MomentDesign.Colors.primary)
                            .frame(width: 44, height: 44, alignment: .center)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Recording Indicator Pill
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.3))
                                .frame(width: 12, height: 12)
                                .scaleEffect(service.isRecording && !service.isPaused ? 1.5 : 1.0)
                                .opacity(service.isRecording && !service.isPaused ? 0.5 : 0.2)
                                .animation(service.isRecording && !service.isPaused ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: service.isRecording && !service.isPaused)
                            
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text(service.isPaused ? "PAUSED" : "RECORDING")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(service.isPaused ? .gray : MomentDesign.Colors.recording)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    Button(action: {
                        service.cancelRecording()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(MomentDesign.Colors.primary)
                            .frame(width: 44, height: 44, alignment: .center)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60) // Account for notch safe area
                .padding(.bottom, 20)
                
                // Timer
                Text(formatDuration(service.elapsedTime))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(MomentDesign.Colors.primary)
                    .monospacedDigit()
                    .padding(.bottom, 16)
                
                if let parentTitle = service.followUpParentTitle {
                    HStack(spacing: 8) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(MomentDesign.Colors.accent)
                        
                        Text("Follow-up to \(parentTitle)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(MomentDesign.Colors.accent)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(MomentDesign.Colors.accent.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
                
                // Audio Waveform Visualizer
                VStack(spacing: 24) {
                    HStack(spacing: 6) {
                        ForEach(0..<service.waveformHeights.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: .infinity)
                                .fill(
                                    LinearGradient(
                                        colors: [MomentDesign.Colors.primary, MomentDesign.Colors.secondary],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 4, height: service.waveformHeights[index])
                                .opacity(opacityForIndex(index))
                                .animation(.easeOut(duration: 0.1), value: service.waveformHeights[index])
                        }
                    }
                    .frame(height: 100)
                    
                    Text(String(format: "Level: %.0fdB", service.audioLevel))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                
                // Live Transcript Section (Full View Scrolling)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let imageData = service.initialImages.first, let uiImage = UIImage(data: imageData) {
                                ZStack(alignment: .bottomTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 140)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                                    
                                    if service.initialImages.count > 1 {
                                        Text("+\(service.initialImages.count - 1)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(.ultraThinMaterial)
                                            .environment(\.colorScheme, .dark)
                                            .clipShape(Capsule())
                                            .padding(12)
                                    }
                                }
                                .padding(.top, 10)
                            }
                            
                            // Header
                            HStack {
                                Text("LIVE TRANSCRIPT")
                                    .font(.system(size: 14, weight: .semibold))
                                    .tracking(1.0)
                                    .foregroundColor(MomentDesign.Colors.textSecondary)
                                
                                Spacer()
                                
                                Text("AI OPTIMIZED")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(MomentDesign.Colors.accent.opacity(0.3), lineWidth: 1)
                                    )
                                    .foregroundColor(MomentDesign.Colors.accent)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 10)
                            
                            if service.transcribedText.isEmpty {
                                Text(service.isRecording ? "Listening..." : "Ready to record")
                                    .font(.system(size: 18))
                                    .foregroundColor(MomentDesign.Colors.textSecondary)
                                    .italic()
                            } else {
                                Text(service.transcribedText)
                                    .font(.system(size: 19))
                                    .foregroundColor(MomentDesign.Colors.text)
                                    .lineSpacing(8)
                                    .id("transcriptText")
                            }
                            
                            HStack(spacing: 8) {
                                if service.isRecording && !service.isPaused {
                                    Text("AI is processing...")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(MomentDesign.Colors.accent)
                                        .opacity(0.8)
                                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: service.isRecording)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 200) // Space for floating controls
                        .onChange(of: service.transcribedText) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("transcriptText", anchor: .bottom)
                            }
                        }
                    }
                    // Fade out top and bottom of scrollview using mask
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.05),
                                .init(color: .black, location: 0.8),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .ignoresSafeArea(edges: .bottom)

            // Action Bar Overlay (Floating Dock)
            VStack {
                Spacer()
                
                HStack(spacing: 36) {
                    // Pause Button
                    VStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                service.togglePause()
                            }
                        }) {
                            Image(systemName: service.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 24))
                                .foregroundColor(MomentDesign.Colors.primary)
                                .frame(width: 56, height: 56)
                                .background(MomentDesign.Colors.surface)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        }
                        Text(service.isPaused ? "RESUME" : "PAUSE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    }
                    
                    // Stop Button
                    VStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                service.stopRecording()
                            }
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(MomentDesign.Colors.destructive)
                                .clipShape(Circle())
                                .shadow(color: MomentDesign.Colors.destructive.opacity(0.3), radius: 15, x: 0, y: 8)
                        }
                        Text("STOP")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    }
                    
                    // Format Button
                    VStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                cycleFormat()
                            }
                        }) {
                            Image(systemName: service.selectedFormat.icon)
                                .font(.system(size: 24))
                                .foregroundColor(MomentDesign.Colors.accent)
                                .frame(width: 56, height: 56)
                                .background(MomentDesign.Colors.surface)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        }
                        Text(service.selectedFormat.displayName.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(MomentDesign.Colors.accent)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .shadow(color: Color.black.opacity(0.1), radius: 30, x: 0, y: 10)
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func opacityForIndex(_ index: Int) -> Double {
        let center = Double(service.waveformHeights.count) / 2.0
        let dist = abs(Double(index) - center)
        let maxDist = center
        return max(0.2, 1.0 - (dist / maxDist) * 0.8)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func cycleFormat() {
        let allFormats = NoteFormat.allCases
        guard let currentIndex = allFormats.firstIndex(of: service.selectedFormat) else {
            service.selectedFormat = .daily
            return
        }
        let nextIndex = (currentIndex + 1) % allFormats.count
        service.selectedFormat = allFormats[nextIndex]
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
