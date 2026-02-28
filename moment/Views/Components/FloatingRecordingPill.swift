//
//  FloatingRecordingPill.swift
//  moment
//
//  Created by wen li on 2026/1/25.
//

import SwiftUI

struct FloatingRecordingPill: View {
    @ObservedObject var service = GlobalAudioService.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                // Recording Indicator
                ZStack {
                    Circle()
                        .fill(MomentDesign.Colors.recording.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .scaleEffect(service.isPaused ? 1.0 : 1.2)
                        .animation(service.isPaused ? .default : .easeInOut(duration: 1).repeatForever(autoreverses: true), value: service.isPaused)
                    
                    Circle()
                        .fill(MomentDesign.Colors.recording)
                        .frame(width: 12, height: 12)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.isPaused ? "Paused" : (service.followUpParentNoteID == nil ? "Recording" : "Follow-up"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MomentDesign.Colors.text)
                        .fixedSize()
                    
                    Text(formatDuration(service.elapsedTime))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                        .fixedSize()
                }
                
                // Fixed spacer to separate text and waveform
                // Spacer(minLength: 8) - Removed to prevent expansion
                
                // Keep the layout compact with HStack spacing only
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(MomentDesign.Colors.accent)
                            .frame(width: 2, height: 12 + CGFloat.random(in: 0...8))
                            .animation(.spring(response: 0.2, dampingFraction: 0.5).delay(Double(index) * 0.05), value: service.elapsedTime)
                    }
                }
                .opacity(service.isPaused ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            .background(MomentDesign.Colors.surface.opacity(0.95))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(MomentDesign.Colors.border.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: MomentDesign.Colors.shadow.opacity(0.25), radius: 10, x: 0, y: 5)
            .contentShape(Rectangle()) // Ensure tap area is solid
            .onTapGesture {
                service.maximize()
            }
            
            // Close Button
            Button(action: {
                service.cancelRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(MomentDesign.Colors.surfaceElevated)
                        .frame(width: 22, height: 22)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                }
            }
            .offset(x: 6, y: -6) // Position at top-trailing edge
        }
        .padding(.horizontal, 4) // slight padding for the close button overhang
        .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
        .animation(.interactiveSpring(), value: offset) // Animate final position settle
        .animation(nil, value: dragOffset) // Do NOT animate the drag itself (1:1 movement)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    offset = CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height)
                    dragOffset = .zero
                }
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
