//
//  AudioPlayerController.swift
//  moment
//
//  Created by wen li on 2026/1/13.
//

import Foundation
import AVFoundation
import Combine

class AudioPlayerController: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func loadAudio(from url: URL) {
        print("Attempting to load audio from: \(url.path)")
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            errorMessage = "音频文件不存在 at path: \(url.lastPathComponent)"
            print("Audio file does not exist at path: \(url.path)")
            return
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("Audio file size: \(fileSize) bytes")
            if fileSize < 100 { // Reduced threshold slightly to be even more permissive
                errorMessage = "音频文件可能损坏 (仅 \(fileSize) 字节)"
                return
            }
        } catch {
            print("Error checking file attributes: \(error)")
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // .defaultToSpeaker is only valid with .playAndRecord. Using it with .playback causes -50 error.
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
            
            // Try loading directly first
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
            } catch {
                print("Direct URL load failed: \(error.localizedDescription). Trying data-based fallback...")
                // Fallback: Load into memory first. This can sometimes bypass OSStatus -50
                let data = try Data(contentsOf: url)
                audioPlayer = try AVAudioPlayer(data: data)
            }
            
            guard let player = audioPlayer else {
                throw NSError(domain: "AudioPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize player"])
            }
            
            player.delegate = self
            if !player.prepareToPlay() {
                print("Warn: prepareToPlay returned false, but proceeding.")
            }
            
            duration = player.duration
            currentTime = 0
            errorMessage = nil
            print("Successfully loaded audio: \(url.lastPathComponent), duration: \(duration)s")
        } catch {
            let nsError = error as NSError
            errorMessage = "Playback failed: \(nsError.localizedDescription)"
            print("Final audio loading error: \(error)")
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        player.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        stopTimer()
        audioPlayer?.stop()
    }
}

extension AudioPlayerController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        player.currentTime = 0
        stopTimer()
    }
}
