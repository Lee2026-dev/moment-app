//
//  GlobalAudioService.swift
//  moment
//
//  Created by wen li on 2026/1/25.
//

import SwiftUI
import Combine
import CoreData

class GlobalAudioService: ObservableObject {
    static let shared = GlobalAudioService()
    
    // State
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var isMinimized = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var waveformHeights: [CGFloat] = Array(repeating: 10, count: 25)
    @Published var transcribedText: String = ""
    @Published var audioLevel: Float = -160.0
    @Published var transcriptionProviderName: String = ""
    
    // Metadata
    @Published var noteID: UUID?
    @Published var audioURL: URL?
    @Published var initialImages: [Data] = []
    @Published var selectedFormat: NoteFormat = .daily
    @Published private(set) var followUpParentNoteID: UUID?
    @Published private(set) var followUpParentTitle: String?
    
    // Dependencies
    private let audioRecorder = AudioRecorder.shared
    private let transcriptionManager = TranscriptionManager.shared
    /// Dedicated service for file-based transcription (correct absolute timestamps)
    private let appleSpeechService = TranscriptionService()
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var recordingStartTime: Date?
    
    private init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind AudioRecorder updates
        audioRecorder.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: &$audioLevel)
            
        audioRecorder.$isPaused
            .receive(on: RunLoop.main)
            .assign(to: &$isPaused)
            
        // Bind Transcription updates
        transcriptionManager.$partialTranscription
            .receive(on: RunLoop.main)
            .assign(to: &$transcribedText)
            
        transcriptionManager.$currentProvider
            .receive(on: RunLoop.main)
            .map { _ in "Apple Speech" }
            .assign(to: &$transcriptionProviderName)
    }
    
    // MARK: - Public Actions
    
    func startRecording(
        initialImages: [Data] = [],
        followUpParentNoteID: UUID? = nil,
        preferredFormat: NoteFormat? = nil
    ) async {
        // Permissions check
        let micGranted = await audioRecorder.requestMicrophonePermission()
        let speechGranted = await transcriptionManager.requestSpeechRecognitionPermission()
        
        guard micGranted && speechGranted else {
            print("Permissions denied") 
            // Handle error state/alert globally if needed
            return
        }
        
        await MainActor.run {
            self.initialImages = initialImages
            self.resetState()
            if let preferredFormat {
                self.selectedFormat = preferredFormat
            }
            if let followUpParentNoteID {
                let context = PersistenceController.shared.container.viewContext
                let rootParentID = NoteService.shared.resolveThreadParentNoteID(from: followUpParentNoteID, in: context)
                self.followUpParentNoteID = rootParentID
                self.followUpParentTitle = NoteService.shared.fetchNote(withID: rootParentID, in: context)?.displayTitle
            } else {
                self.followUpParentNoteID = nil
                self.followUpParentTitle = nil
            }
            
            // 1. ID & URL
            let newID = UUID()
            self.noteID = newID
            self.audioURL = AudioFileManager.shared.audioURL(for: newID)
            
            guard let url = self.audioURL else { return }
            
            // 2. Transcription
            Task {
                try? await self.transcriptionManager.startRealTimeTranscription()
            }
            
            // 3. Audio Recorder Buffer -> Transcription
            self.audioRecorder.bufferSubject
                .receive(on: DispatchQueue.main)
                .sink { [weak self] buffer in
                    self?.transcriptionManager.appendAudioBuffer(buffer)
                }
                .store(in: &self.cancellables)
            
            // 4. Start Recording
            if self.audioRecorder.startRecording(to: url) {
                self.isRecording = true
                self.isMinimized = false // Start full screen
                self.recordingStartTime = Date()
                self.startTimer()
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop components
        let audio_url = audioRecorder.stopRecording()
        transcriptionManager.stopTranscription()
        
        stopTimer()
        
        // Save note first, then generate segments from the saved audio file
        // (file-based transcription gives correct absolute timestamps)
        saveNote()
        
        // --- Gemini Enhancement Integration ---
        // --- Automatic Summarization ---
        if let currentNoteID = noteID, !transcribedText.isEmpty {
            let textToSummarize = transcribedText
            Task {
                do {
                    // Call the new AIService
                    let result = try await AIService.shared.summarize(
                        text: textToSummarize,
                        format: self.selectedFormat,
                        noteID: currentNoteID
                    )
                    
                    await MainActor.run {
                        let context = PersistenceController.shared.container.viewContext
                        context.performAndWait {
                            let request: NSFetchRequest<Note> = Note.fetchRequest()
                            request.predicate = NSPredicate(format: "id == %@", currentNoteID as CVarArg)
                            
                            if let notes = try? context.fetch(request), let note = notes.first {
                                note.content = result.summary
                                // Only update title if it's the default one
                                note.title = result.suggestedTitle
                                note.updatedAt = Date()
                                note.syncStatus = 1
                                
                                do {
                                    try context.save()
                                    print("Automatic summarization completed for Note ID: \(currentNoteID)")
                                } catch {
                                    print("Failed to persist summarization result locally: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        Task {
                            await SyncEngine.shared.sync()
                        }
                    }
                } catch {
                    print("Automatic summarization failed: \(error.localizedDescription)")
                }
            }
        }
        // ------------------------------------
        // ------------------------------------
        
        // Reset UI State
        resetState()
        isRecording = false
        isMinimized = false
    }
    
    func cancelRecording() {
        audioRecorder.cancelRecording()
        transcriptionManager.stopTranscription()
        stopTimer()
        resetState()
        isRecording = false
        isMinimized = false
    }
    
    func togglePause() {
        if isPaused {
            audioRecorder.resumeRecording()
            startTimer()
        } else {
            audioRecorder.pauseRecording()
            stopTimer()
        }
    }
    
    func minimize() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isMinimized = true
        }
    }
    
    func maximize() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isMinimized = false
        }
    }
    
    // MARK: - Private Helpers
    
    private func resetState() {
        elapsedTime = 0
        waveformHeights = Array(repeating: 10, count: 25)
        transcribedText = ""
        followUpParentNoteID = nil
        followUpParentTitle = nil
        cancellables.removeAll()
        timer?.invalidate()
        timer = nil
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Update duration
            self.elapsedTime = self.audioRecorder.recordingDuration
            
            // Update waveform
            self.updateWaveform()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateWaveform() {
        withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
            // Map -60dB...0dB to 10...100 height
            let normalizedLevel = max(0, (Double(self.audioLevel) + 60) / 60.0)
            
            for i in 0..<self.waveformHeights.count {
                let center = Double(self.waveformHeights.count) / 2.0
                let dist = abs(Double(i) - center)
                let factor = max(0.1, 1.0 - (dist / center))
                
                let baseHeight: CGFloat = 10
                let variation = CGFloat.random(in: 0.8...1.2)
                self.waveformHeights[i] = baseHeight + CGFloat(normalizedLevel * 100 * factor * variation)
            }
        }
    }
    
    private func saveNote() {
        guard let noteID = noteID, let audioURL = audioURL else { return }
        
        let context = PersistenceController.shared.container.viewContext
        let isFollowUp = followUpParentNoteID != nil
        let title = isFollowUp ? "Follow-up \(formatDateForTitle(Date()))" : "录音笔记 \(formatDateForTitle(Date()))"
        
        context.performAndWait {
            if self.initialImages.isEmpty {
                NoteService.shared.createNote(
                    withID: noteID,
                    audioURL: audioURL,
                    transcribedText: self.transcribedText,
                    title: title,
                    imageData: nil,
                    format: self.selectedFormat,
                    parentNoteID: self.followUpParentNoteID,
                    in: context
                )
            } else {
                NoteService.shared.createNote(
                    withID: noteID,
                    audioURL: audioURL,
                    transcribedText: self.transcribedText,
                    title: title,
                    images: self.initialImages,
                    format: self.selectedFormat,
                    parentNoteID: self.followUpParentNoteID,
                    in: context
                )
            }
        }
        
        // Generate properly-timestamped segments using file-based Apple Speech
        // (real-time SFSpeechAudioBufferRecognitionRequest timestamps are relative to
        //  the recognition window, not the full recording — they cannot be used for highlighting)
        let capturedNoteID = noteID
        let capturedAudioURL = audioURL
        let speechService = appleSpeechService
        Task {
            guard let result = await speechService.transcribeAudioWithSegments(from: capturedAudioURL),
                  !result.segments.isEmpty else {
                print("File-based transcription returned no segments for note \(capturedNoteID)")
                await SyncEngine.shared.sync()
                return
            }
            
            let bgContext = PersistenceController.shared.container.newBackgroundContext()
            bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            try? await bgContext.perform {
                let request: NSFetchRequest<Note> = Note.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", capturedNoteID as CVarArg)
                if let note = (try? bgContext.fetch(request))?.first {
                    note.setTranscriptSegments(result.segments)
                    note.syncStatus = 1
                    try? bgContext.save()
                    print("Saved \(result.segments.count) file-based segments for note \(capturedNoteID)")
                }
            }
            await SyncEngine.shared.sync()
        }
        
        Task {
            await SyncEngine.shared.sync()
        }
    }
    
    private func formatDateForTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 H:mm"
        return formatter.string(from: date)
    }
}
