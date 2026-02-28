//
//  AudioRecordingController.swift
//  moment
//
//  Created by wen li on 2026/1/13.
//

import Foundation
import SwiftUI
import AVFoundation
import Speech
import Combine


class AudioRecordingController: ObservableObject {
    @Published var isRecording = false
    @Published var recordingStartTime: Date?
    @Published var elapsedTime: TimeInterval = 0
    @Published var hasPermission = false
    @Published var audioURL: URL?
    @Published var showingError = false
    @Published var errorMessage = ""
    
    private var timer: Timer?
    private let audioRecorder = AudioRecorder.shared
    
    func checkPermissionAndStart() {
        Task {
            let microphoneGranted = await audioRecorder.requestMicrophonePermission()
            let speechGranted = await requestSpeechRecognitionPermission()

            if microphoneGranted && speechGranted {
                await MainActor.run {
                    hasPermission = true
                    startRecording()
                }
            } else {
                await MainActor.run {
                    hasPermission = false
                    errorMessage = "需要麦克风和语音识别权限才能录音"
                    showingError = true
                }
            }
        }
    }

    func startRecording() {
        audioURL = AudioFileManager.shared.createNewAudioURL()
        if let url = audioURL, audioRecorder.startRecording(to: url) {
            isRecording = true
            recordingStartTime = Date()
            startTimer()
        } else {
            errorMessage = "无法开始录音"
            showingError = true
        }
    }

    func stopRecording(onComplete: @escaping (URL, UUID, String?) -> Void, dismiss: DismissAction) {
        audioRecorder.stopRecording()
        stopTimer()
        isRecording = false

        guard let url = audioURL else { return }

        Task {
            // Wait for file to be flushed
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            // Verify file exists and has size
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: url.path) {
                print("Recording failed: File does not exist at \(url.path)")
                await MainActor.run {
                    errorMessage = "录音保存失败：文件不存在"
                    showingError = true
                }
                return
            }
            
            do {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("Recorded file size: \(fileSize) bytes")
                
                if fileSize < 100 {
                    print("Recording failed: File too small (\(fileSize) bytes)")
                    await MainActor.run {
                        errorMessage = "录音失败：没有检测到声音或录音时间太短"
                        showingError = true
                    }
                    return
                }
            } catch {
                print("Error checking recorded file: \(error)")
            }
            
            let transcriptionService = TranscriptionService()
            let text = await transcriptionService.transcribeAudio(from: url)

            await MainActor.run {
                let noteID = UUID()
                onComplete(url, noteID, text)
                dismiss()
            }
        }
    }

    private func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            if let startTime = self?.recordingStartTime {
                self?.elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
