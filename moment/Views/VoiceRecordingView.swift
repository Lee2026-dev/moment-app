//
//  VoiceRecordingView.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import Combine
import UIKit
import SwiftUI
import AVFoundation

/// Recording state enum
enum RecordingState {
    case idle
    case recording
    case stopped
    case error
}

struct VoiceRecordingView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var transcriptionService = TranscriptionService()
    @State private var recordingState: RecordingState = .idle
    @State private var showPermissionAlert = false
    @State private var permissionDenied = false
    @Environment(\.colorScheme) var colorScheme
    @State private var noteID: UUID?
    @State private var transcribedText: String?
    
    let onRecordingComplete: (URL?, UUID?, String?) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Recording indicator
            if recordingState == .recording {
                recordingIndicator
            }
            
            // Timer display
            if recordingState == .recording || recordingState == .stopped {
                timerDisplay
            }
            
            // Status message
            statusMessage
            
            Spacer()
            
            // Record/Stop button
            recordButton
            
            // Cancel button (only when not recording)
            if recordingState != .recording {
                cancelButton
            }
            
            Spacer()
        }
        .padding()
        .background(MomentDesign.Colors.background)
        .alert("Microphone Permission Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) {
                onCancel()
            }
        } message: {
            Text("Please enable microphone access in Settings to record voice notes.")
        }
        .alert("Permission Denied", isPresented: $permissionDenied) {
            Button("OK", role: .cancel) {
                onCancel()
            }
        } message: {
            Text("Microphone permission is required to record voice notes. Please enable it in Settings.")
        }
    }
    
    // MARK: - Recording Indicator
    private var recordingIndicator: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(MomentDesign.Colors.recording)
                .frame(width: 20, height: 20)
                .opacity(recordingState == .recording ? 1.0 : 0.3)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: recordingState == .recording
                )
            
            Text("Recording...")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(MomentDesign.Colors.textSecondary)
        }
    }
    
    // MARK: - Timer Display
    private var timerDisplay: some View {
        Text(formatDuration(audioRecorder.recordingDuration))
            .font(.system(size: 64, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .foregroundColor(MomentDesign.Colors.text)
    }
    
    // MARK: - Status Message
    private var statusMessage: some View {
        Group {
            if let errorMessage = audioRecorder.errorMessage ?? transcriptionService.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MomentDesign.Colors.destructive)
                    .multilineTextAlignment(.center)
            } else if transcriptionService.isTranscribing {
                VStack(spacing: 8) {
                    ProgressView(value: transcriptionService.transcriptionProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("Transcribing...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                }
                .padding(.horizontal)
            } else if recordingState == .idle {
                Text("Tap the button to start recording")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(MomentDesign.Colors.textSecondary)
            } else if recordingState == .stopped {
                Text("Recording stopped")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(MomentDesign.Colors.textSecondary)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Record Button
    private var recordButton: some View {
        Button(action: handleRecordButtonTap) {
            ZStack {
                Circle()
                    .fill(recordingState == .recording ? MomentDesign.Colors.recording : MomentDesign.Colors.accent)
                    .frame(width: 80, height: 80)
                    .shadow(color: (recordingState == .recording ? MomentDesign.Colors.recording : MomentDesign.Colors.accent).opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: recordingState == .recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
        }
        .disabled(recordingState == .stopped)
    }
    
    // MARK: - Cancel Button
    private var cancelButton: some View {
        Button(action: handleCancel) {
            Text("Cancel")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(MomentDesign.Colors.text)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(MomentDesign.Colors.secondary.opacity(0.1))
                .cornerRadius(20)
        }
    }
    
    // MARK: - Actions
    private func handleRecordButtonTap() {
        switch recordingState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .stopped, .error:
            break
        }
    }
    
    private func startRecording() {
        Task {
            // Check permission
            if !audioRecorder.hasMicrophonePermission() {
                let granted = await audioRecorder.requestMicrophonePermission()
                if !granted {
                    permissionDenied = true
                    return
                }
            }
            
            // Generate a note ID for this recording
            let newNoteID = UUID()
            noteID = newNoteID
            let audioURL = AudioFileManager.shared.audioURL(for: newNoteID)
            
            // Start recording
            if audioRecorder.startRecording(to: audioURL) {
                recordingState = .recording
            } else {
                recordingState = .error
                noteID = nil
            }
        }
    }
    
    private func stopRecording() {
        guard let audioURL = audioRecorder.stopRecording() else {
            recordingState = .error
            noteID = nil
            return
        }
        
        recordingState = .stopped
        
        // Start transcription after a brief delay to ensure file is fully written
        Task {
            // Wait a moment for the file to be fully written to disk
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Verify file exists before transcribing
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                print("Error: Audio file does not exist at \(audioURL.path)")
                await MainActor.run {
                    onRecordingComplete(audioURL, noteID, nil)
                }
                return
            }
            
            // Check file size to ensure it's not empty and has reasonable content
            if let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
               let fileSize = attributes[.size] as? Int64 {
                if fileSize == 0 {
                    print("Error: Audio file is empty")
                    await MainActor.run {
                        onRecordingComplete(audioURL, noteID, nil)
                    }
                    return
                } else if fileSize < 1000 {
                    // File is very small (less than 1KB), likely no audio content
                    print("Warning: Audio file is very small (\(fileSize) bytes), may contain no audio")
                }
            }
            
            // Check audio file duration using AVAsset
            let asset = AVAsset(url: audioURL)
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                print("Audio file duration: \(durationSeconds) seconds")
                
                if durationSeconds < 0.5 {
                    print("Warning: Audio file is very short (\(durationSeconds) seconds), may not contain speech")
                }
            } catch {
                print("Could not read audio file duration: \(error.localizedDescription)")
            }
            
            print("Starting transcription for file: \(audioURL.path)")
            let text = await transcriptionService.transcribeAudio(from: audioURL)
            transcribedText = text
            
            if let text = text, !text.isEmpty {
                print("Transcription successful: \(text.prefix(50))...")
            } else {
                let errorMsg = transcriptionService.errorMessage ?? "No speech detected"
                print("Transcription failed or returned nil. Error: \(errorMsg)")
                
                // If it's a "no speech detected" error, provide helpful context
                if errorMsg.contains("No speech detected") {
                    print("Note: This often happens in the iOS Simulator. Try recording on a real device for best results.")
                }
            }
            
            // Call completion handler with the audio URL, note ID, and transcribed text
            // Even if transcription fails, we still save the note with the audio file
            await MainActor.run {
                onRecordingComplete(audioURL, noteID, text)
            }
        }
    }
    
    private func handleCancel() {
        if recordingState == .recording {
            audioRecorder.cancelRecording()
            // Delete the audio file if it was created
            if let noteID = noteID {
                AudioFileManager.shared.deleteAudioFile(for: noteID)
            }
        }
        noteID = nil
        onCancel()
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    // MARK: - Helper Methods
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    VoiceRecordingView(
        onRecordingComplete: { url, noteID, transcribedText in
            print("Recording completed:")
            print("  Audio URL: \(url?.absoluteString ?? "nil")")
            print("  Note ID: \(noteID?.uuidString ?? "nil")")
            print("  Transcribed Text: \(transcribedText ?? "nil")")
        },
        onCancel: {
            print("Recording cancelled")
        }
    )
}

