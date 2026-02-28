//
//  AudioRecordingOverlay.swift
//  moment
//
//  Created by wen li on 2026/1/25.
//

import SwiftUI

struct AudioRecordingOverlay: View {
    @ObservedObject var service = GlobalAudioService.shared
    
    var body: some View {
        if service.isRecording {
            ZStack {
                if service.isMinimized {
                    VStack {
                        Spacer()
                        FloatingRecordingPill()
                            .padding(.bottom, 120) // Above tab bar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                } else {
                    AudioRecordingView()
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: service.isMinimized)
            .animation(.easeInOut, value: service.isRecording)
            .ignoresSafeArea()
        }
    }
}
