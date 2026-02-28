//
//  MiniAudioPlayerView.swift
//  moment
//
//  Compact audio player for voice notes in edit view
//

import SwiftUI

struct MiniAudioPlayerView: View {
    let audioURL: URL
    /// Shared controller so transcript highlighting can observe playback time.
    /// If nil, an internal controller is created (legacy behaviour).
    @ObservedObject var controller: AudioPlayerController
    
    init(audioURL: URL, controller: AudioPlayerController) {
        self.audioURL = audioURL
        self.controller = controller
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            Button(action: {
                controller.togglePlayPause()
            }) {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(MomentDesign.Colors.accent)
            }
            
            // Time and Progress
            VStack(spacing: 4) {
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
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                    Spacer()
                    Text(formatTime(controller.duration))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(MomentDesign.Colors.surfaceElevated)
        .cornerRadius(12)
        .shadow(color: MomentDesign.Colors.shadow.opacity(0.02), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
