//  WaveformView.swift
//  moment
//
//  Created by wen li on 2026/1/8.
//

import SwiftUI

struct WaveformView: View {
    let isRecording: Bool
    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange)
                    .frame(width: 6, height: waveformHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.3)
                        .delay(Double(index) * 0.05)
                        .repeatForever(autoreverses: true),
                        value: isRecording
                    )
            }
        }
        .frame(height: 40)
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    phase = 1
                }
            } else {
                phase = 0
            }
        }
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        if !isRecording {
            return 8
        }
        let base = 8.0
        let maxHeight = 36.0
        let variation = sin(Double(index) * 0.5 + phase * .pi * 2)
        return base + (maxHeight - base) * CGFloat((variation + 1) / 2)
    }
}