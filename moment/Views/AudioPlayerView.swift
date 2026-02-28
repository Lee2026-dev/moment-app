//
//  AudioPlayerView.swift
//  moment
//
//  Created by wen li on 2026/1/13.
//

import SwiftUI

struct AudioPlayerView: View {
    let audioURL: URL
    @StateObject private var controller = AudioPlayerController()
    
    var body: some View {
        VStack(spacing: 12) {
            // Play/Pause Button and Time Display
            HStack(spacing: 16) {
                Button(action: {
                    controller.togglePlayPause()
                }) {
                    Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(MomentDesign.Colors.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Progress Slider
                    Slider(
                        value: Binding(
                            get: { controller.currentTime },
                            set: { controller.seek(to: $0) }
                        ),
                        in: 0...max(controller.duration, 0.1)
                    )
                    .accentColor(MomentDesign.Colors.accent)
                    .disabled(controller.duration == 0)
                    
                    // Time Labels
                    HStack {
                        Text(formatTime(controller.currentTime))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                        Spacer()
                        Text(formatTime(controller.duration))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    }
                }
            }
            
            // Error Message
            if let error = controller.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MomentDesign.Colors.destructive)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(MomentDesign.Colors.surfaceElevated)
        .cornerRadius(16)
        .shadow(color: MomentDesign.Colors.shadow.opacity(0.02), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(MomentDesign.Colors.border.opacity(0.5), lineWidth: 0.5)
        )
        .onAppear {
            controller.loadAudio(from: audioURL)
        }
        .onDisappear {
            controller.stop()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
