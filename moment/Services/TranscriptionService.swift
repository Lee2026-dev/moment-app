//
//  TranscriptionService.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import Foundation
import Speech
import AVFoundation
import Combine

/// Manages speech-to-text transcription using on-device Speech framework
@MainActor
class TranscriptionService: NSObject, ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var locale: Locale
    
    init(locale: Locale = Locale(identifier: "zh-CN")) {
        self.locale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        super.init()
        // Configure speech recognizer
        speechRecognizer?.delegate = self
    }
    
    /// Checks if speech recognition is available
    var isAvailable: Bool {
        return speechRecognizer != nil && speechRecognizer!.isAvailable
    }
    
    /// Checks if speech recognition permission is granted
    func hasSpeechRecognitionPermission() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    /// Requests speech recognition permission
    /// - Returns: True if permission is granted
    func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    /// Transcribes an audio file to text
    /// - Parameter audioURL: The URL of the audio file to transcribe
    /// - Returns: The transcribed text, or nil if transcription failed
    func transcribeAudio(from audioURL: URL) async -> String? {
        let result = await transcribeAudioWithSegments(from: audioURL)
        return result?.text
    }
    
    /// Transcribes an audio file and returns both text and timestamped segments
    /// - Parameter audioURL: The URL of the audio file to transcribe
    /// - Returns: A tuple of (text, segments) or nil if transcription failed
    func transcribeAudioWithSegments(from audioURL: URL) async -> (text: String, segments: [TranscriptSegment])? {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is not available"
            return nil
        }
        
        // Check permission
        if !hasSpeechRecognitionPermission() {
            let granted = await requestSpeechRecognitionPermission()
            if !granted {
                errorMessage = "Speech recognition permission denied"
                return nil
            }
        }
        
        isTranscribing = true
        transcriptionProgress = 0.0
        errorMessage = nil
        
        // Verify the file exists and is readable
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "Audio file does not exist"
            isTranscribing = false
            return nil
        }
        
        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: audioURL.path) else {
            errorMessage = "Audio file is not readable"
            isTranscribing = false
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            
            var finalResult: (text: String, segments: [TranscriptSegment])?
            var hasResumed = false
            
            let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self, !hasResumed else {
                    return
                }
                
                if let error = error {
                    // Check if it's a cancellation (not a real error)
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        // Cancellation - return final result if we have it
                        self.isTranscribing = false
                        hasResumed = true
                        continuation.resume(returning: finalResult)
                        return
                    }
                    
                    // Handle specific error codes
                    if nsError.domain == "kAFAssistantErrorDomain" {
                        switch nsError.code {
                        case 1110:
                            self.errorMessage = "No speech detected in recording. This may happen in the iOS Simulator. Try on a real device."
                            print("Transcription error: No speech detected (code 1110)")
                        case 1700:
                            self.errorMessage = "Speech recognition is currently unavailable"
                            print("Transcription error: Recognition unavailable (code 1700)")
                        case 1701:
                            self.errorMessage = "Network error during transcription"
                            print("Transcription error: Network error (code 1701)")
                        default:
                            self.errorMessage = "Transcription error: \(error.localizedDescription)"
                            print("Transcription error: \(error.localizedDescription)")
                        }
                    } else {
                        self.errorMessage = "Transcription error: \(error.localizedDescription)"
                        print("Transcription error: \(error.localizedDescription)")
                    }
                    
                    print("Error domain: \(nsError.domain), code: \(nsError.code)")
                    self.isTranscribing = false
                    self.transcriptionProgress = 0.0
                    hasResumed = true
                    continuation.resume(returning: nil)
                    return
                }
                
                if let result = result {
                    let transcribedText = result.bestTranscription.formattedString
                    
                    // Map SFTranscriptionSegment -> TranscriptSegment, then merge into sentences
                    let rawSegments: [TranscriptSegment] = result.bestTranscription.segments.map { seg in
                        TranscriptSegment(
                            text: seg.substring,
                            startTime: seg.timestamp,
                            endTime: seg.timestamp + seg.duration
                        )
                    }
                    let segments = self.mergeIntoSentences(rawSegments)
                    
                    if result.isFinal {
                        self.isTranscribing = false
                        self.transcriptionProgress = 1.0
                        finalResult = transcribedText.isEmpty ? nil : (transcribedText, segments)
                        hasResumed = true
                        continuation.resume(returning: finalResult)
                    } else {
                        self.transcriptionProgress = min(0.9, self.transcriptionProgress + 0.1)
                        finalResult = transcribedText.isEmpty ? nil : (transcribedText, segments)
                    }
                }
            }
            
            // Set a timeout to prevent hanging forever
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds timeout
                if !hasResumed {
                    task.cancel()
                    self.isTranscribing = false
                    self.errorMessage = "Transcription timed out"
                    hasResumed = true
                    continuation.resume(returning: finalResult)
                }
            }
        }
    }
    
    // MARK: - Real-time Transcription
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var partialTranscription: String = ""
    /// The timestamped segments from the most recent real-time transcription.
    /// Populated on every recognition result; remains set when stopTranscription() is called.
    @Published var lastSegments: [TranscriptSegment] = []
    
    /// Starts real-time transcription
    func startRealTimeTranscription() async throws {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "TranscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not available"])
        }
        
        if !hasSpeechRecognitionPermission() {
            let granted = await requestSpeechRecognitionPermission()
            if !granted {
                throw NSError(domain: "TranscriptionService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
            }
        }
        
        // Cancel existing task
        stopTranscription()
        
        isTranscribing = true
        errorMessage = nil
        partialTranscription = ""
        lastSegments = []
        transcriptionProgress = 0
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13, *) {
            request.addsPunctuation = true
        }
        request.taskHint = .dictation
        
        // Keep a reference to the request so we can append audio to it
        recognitionRequest = request
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.partialTranscription = result.bestTranscription.formattedString
                // Capture timestamped segments on every callback (partial and final)
                self.lastSegments = self.mergeIntoSentences(
                    result.bestTranscription.segments.map { seg in
                        TranscriptSegment(
                            text: seg.substring,
                            startTime: seg.timestamp,
                            endTime: seg.timestamp + seg.duration
                        )
                    }
                )
            }
            
            if let error = error {
                let nsError = error as NSError
                // Ignore "cancelled" or "finishing" errors often seen when stopping manually
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                    return
                }
                print("Real-time transcription error: \(error)")
                self.errorMessage = error.localizedDescription
                self.stopTranscription()
            }
        }
    }
    
    /// Appends audio buffer to the current recognition request
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
    
    /// Stops the current transcription
    func stopTranscription() {
        if isTranscribing {
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            
            // Wait a moment for final results? In real-time UI, we just stop.
            recognitionRequest = nil
            recognitionTask = nil
            isTranscribing = false
        }
    }
    
    // MARK: - Segment Merging
    
    /// Merges raw Apple Speech per-character/word segments into sentence-level groups.
    /// Rules:
    ///  • 。！？  → always end a sentence
    ///  • ，      → end a sentence only when accumulated text ≥ 8 chars
    ///  • gap > 1s → force a new sentence
    ///  • > 40 chars → force split
    private func mergeIntoSentences(_ raw: [TranscriptSegment]) -> [TranscriptSegment] {
        guard !raw.isEmpty else { return [] }
        
        let hardEnders: Set<Character> = ["。", "！", "？", "!", "?"]
        let softEnders: Set<Character> = [",", "，", ";", "；"]
        let maxLength = 40
        let softMinLength = 8
        let gapThreshold: TimeInterval = 1.0
        
        var result: [TranscriptSegment] = []
        var accText = ""
        var startTime: TimeInterval = raw[0].startTime
        var prevEndTime: TimeInterval = raw[0].startTime
        
        for seg in raw {
            let gap = seg.startTime - prevEndTime
            let wouldExceedMax = (accText + seg.text).count > maxLength
            let isHardEnd = seg.text.last.map { hardEnders.contains($0) } ?? false
            let isSoftEnd = seg.text.last.map { softEnders.contains($0) } ?? false
            
            // Flush current group if gap or length limit
            if !accText.isEmpty && (gap > gapThreshold || wouldExceedMax) {
                result.append(TranscriptSegment(text: accText, startTime: startTime, endTime: prevEndTime))
                accText = ""
                startTime = seg.startTime
            }
            
            accText += seg.text
            prevEndTime = seg.endTime
            
            // Flush on sentence-ending punctuation
            if isHardEnd || (isSoftEnd && accText.count >= softMinLength) {
                result.append(TranscriptSegment(text: accText, startTime: startTime, endTime: seg.endTime))
                accText = ""
                startTime = seg.endTime
            }
        }
        
        // Flush any trailing text
        if !accText.isEmpty {
            result.append(TranscriptSegment(text: accText, startTime: startTime, endTime: prevEndTime))
        }
        
        return result
    }


}

    // MARK: - SFSpeechRecognizerDelegate
extension TranscriptionService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                errorMessage = "Speech recognition became unavailable"
            }
        }
    }
}

