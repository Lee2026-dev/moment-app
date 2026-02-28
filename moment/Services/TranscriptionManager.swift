//
//  TranscriptionManager.swift
//  moment
//
//  Created by Sisyphus on 2026/01/26.
//

import Foundation
import Combine
import AVFoundation
import SwiftUI

enum TranscriptionProvider {
    case appleSpeech
}

@MainActor
class TranscriptionManager: ObservableObject {
    static let shared = TranscriptionManager()
    
    // Settings
    @AppStorage("transcriptionLanguage") var language: String = "zh"
    
    // State
    @Published var partialTranscription: String = ""
    /// The timestamped segments from the most recent real-time transcription.
    @Published var lastSegments: [TranscriptSegment] = []
    @Published var currentProvider: TranscriptionProvider = .appleSpeech
    
    // Services
    private let appleSpeechService = TranscriptionService()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Forward partial text from Apple Speech service
        appleSpeechService.$partialTranscription
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.partialTranscription = text
            }
            .store(in: &cancellables)
        
        // Forward segments from Apple Speech service
        appleSpeechService.$lastSegments
            .receive(on: RunLoop.main)
            .sink { [weak self] segments in
                self?.lastSegments = segments
            }
            .store(in: &cancellables)
    }
    
    func requestSpeechRecognitionPermission() async -> Bool {
        return await appleSpeechService.requestSpeechRecognitionPermission()
    }
    
    func startRealTimeTranscription() async throws {
        partialTranscription = ""
        lastSegments = []
        currentProvider = .appleSpeech
        try await appleSpeechService.startRealTimeTranscription()
    }
    
    func stopTranscription() {
        appleSpeechService.stopTranscription()
    }
    
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        appleSpeechService.appendAudioBuffer(buffer)
    }
}
