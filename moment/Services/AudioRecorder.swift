//
//  AudioRecorder.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import AVFoundation
import Combine

/// Manages audio recording using AVAudioEngine for real-time buffer access
class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorder()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = -160.0
    @Published var sampleRate: Double = 44100.0
    @Published var isPaused = false
    @Published var errorMessage: String?
    
    // Subject to stream audio buffers for real-time processing (transcription)
    let bufferSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingTimer: Timer?
    private var recordingURL: URL?
    
    override init() {
        super.init()
    }
    
    /// Sets up the audio session for recording
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        // Use playAndRecord to allow both recording and playback
        // .measurement mode is recommended for Speech Recognition (removes gain control/signal processing)
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    /// Requests microphone permission
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func hasMicrophonePermission() -> Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }
    
    /// Starts recording audio to a file and streams buffers
    func startRecording(to url: URL) -> Bool {
        if isRecording { stopRecording() }
        
        guard Thread.isMainThread else {
            var result = false
            DispatchQueue.main.sync { result = self.startRecording(to: url) }
            return result
        }
        
        errorMessage = nil
        recordingURL = url
        isPaused = false
        
        do {
            try setupAudioSession()
            
            // Ensure directory exists
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            
            // Setup Engine
            audioEngine = AVAudioEngine()
            guard let engine = audioEngine else { return false }
            
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            
            // Validate format (Simulator often returns 0 sample rate)
            if format.sampleRate == 0 || format.channelCount == 0 {
                print("Invalid input format: \(format). Trying to force standard format.")
                // Attempt to reset input node? 
                // Just fail gracefully for now or try to use a standard format if tap allows (it usually doesn't if hardware is invalid)
                 errorMessage = "Invalid audio input format (hardware not available?)"
                 return false
            }
            
            self.sampleRate = format.sampleRate
            
            // Setup Audio File
            // Use the INPUT format's sample rate and channels to avoid mismatched buffer writes
            // We still encode to AAC (m4a) but match the source characteristics
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // Create the file. We specify commonFormat: .pcmFormatFloat32 because engine buffers are usually Float32.
            // We set interleaved: false because engine buffers are usually non-interleaved.
            audioFile = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            
            // Install Tap
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
                guard let self = self, !self.isPaused else { return }
                
                // Calculate audio level
                self.calculateLevel(from: buffer)
                
                // Stream buffer for transcription
                self.bufferSubject.send(buffer)
                
                // Write to file
                do {
                    try self.audioFile?.write(from: buffer)
                } catch {
                    print("Error writing audio file: \(error)")
                }
            }
            
            self.sampleRate = format.sampleRate
            
            try engine.start()
            
            isRecording = true
            recordingDuration = 0
            startTimer()
            
            print("Audio Engine started recording to: \(url.path)")
            return true
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("Start recording error: \(error)")
            stopRecording() // cleanup
            return false
        }
    }
    
    /// Stops the current recording
    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        audioFile = nil // This closes the file
        
        stopTimer()
        isRecording = false
        isPaused = false
        
        let url = recordingURL
        recordingURL = nil
        
        // Deactivate session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        return url
    }
    
    func pauseRecording() {
        guard isRecording else { return }
        isPaused = true
        audioEngine?.pause()
        stopTimer()
    }
    
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        isPaused = false
        try? audioEngine?.start()
        startTimer()
    }
    
    func cancelRecording() {
        _ = stopRecording()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        recordingDuration = 0
    }
    
    private func startTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func calculateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataArray = UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength))
        
        var rms: Float = 0
        if buffer.frameLength > 0 {
            for i in 0..<Int(buffer.frameLength) {
                rms += channelDataArray[i] * channelDataArray[i]
            }
            rms = sqrt(rms / Float(buffer.frameLength))
        }
        
        // Convert to dB
        let avgPower = 20 * log10(rms)
        
        DispatchQueue.main.async {
            // Clamp between -160 and 0
            self.audioLevel = max(-160, min(0, avgPower))
        }
    }
    
    deinit {
        stopRecording()
    }
}
// MARK: - AVAudioRecorderDelegate
extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            errorMessage = "Recording finished with errors"
            isRecording = false
            recordingTimer?.invalidate()
            recordingTimer = nil
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        errorMessage = "Recording error: \(error?.localizedDescription ?? "Unknown error")"
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

