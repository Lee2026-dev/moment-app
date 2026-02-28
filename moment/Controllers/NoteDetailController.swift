//
//  NoteDetailController.swift
//  moment
//
//  Created by wen li on 2026/1/13.
//

import Foundation
import SwiftUI
import CoreData
import Combine


class NoteDetailController: ObservableObject {
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var transcript: String = ""
    @Published var tags: Set<Tag> = []
    @Published var workingImages: [Data] = []
    @Published var format: NoteFormat = .daily
    
    private var note: Note
    private let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    private var lastLoadedTitle: String = ""
    private var lastLoadedContent: String = ""
    private var lastLoadedTranscript: String = ""
    
    init(note: Note, viewContext: NSManagedObjectContext) {
        self.note = note
        self.viewContext = viewContext
        refresh()
        observeManagedObjectChanges()
    }
    
    func refresh() {
        self.title = note.title ?? ""
        self.content = note.content ?? ""
        self.transcript = note.transcript ?? ""
        self.tags = note.tags as? Set<Tag> ?? []
        self.workingImages = note.allImageData
        self.format = note.formatEnum
        self.lastLoadedTitle = self.title
        self.lastLoadedContent = self.content
        self.lastLoadedTranscript = self.transcript
        print("refresh.......")
    }
    
    func refreshIfNoPendingLocalEdits() {
        guard !hasPendingTextEdits else { return }
        refresh()
    }
    
    var hasAudio: Bool {
        return note.hasAudio
    }
    
    var noteID: UUID? {
        return note.id
    }
    
    var audioFileURL: URL? {
        return note.audioFileURL
    }
    
    var transcriptSegments: [TranscriptSegment] {
        return note.parsedTranscriptSegments
    }
    
    var timestamp: Date {
        return note.timestamp ?? Date()
    }
    
    func switchToNote(_ newNote: Note) {
        guard newNote.objectID != note.objectID else { return }
        
        saveOrDeleteOnExit()
        note = newNote
        refresh()
    }
    
    var shouldDeleteOnExit: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !hasAudio &&
        workingImages.isEmpty
    }
    
    func saveOrDeleteOnExit() {
        guard note.managedObjectContext != nil, !note.isDeleted else { return }
        
        if shouldDeleteOnExit {
            NoteService.shared.deleteNote(note, in: viewContext)
            return
        }
        
        saveNote()
    }
    
    func saveNote() {
        guard note.managedObjectContext != nil, !note.isDeleted else { return }
        
        viewContext.performAndWait {
            viewContext.refresh(note, mergeChanges: true)
        }
        
        guard hasAnyEditableChanges() else { return }
        
        let titleToSave = title
        let contentToSave = content
        let transcriptToSave = transcript
        let tagsToSave = tags
        let imagesToSave = workingImages
        
        if note.allImageData != imagesToSave {
             NoteService.shared.replaceImages(imagesToSave, for: note, in: viewContext)
        }
        
        note.title = titleToSave
        note.content = contentToSave
        
        if note.hasAudio {
            note.transcript = transcriptToSave
        }
        
        note.formatEnum = format
        
        // Update tags on main context immediately
        let currentTags = note.tags as? Set<Tag> ?? []
        let tagsToRemove = currentTags.subtracting(tagsToSave)
        let tagsToAdd = tagsToSave.subtracting(currentTags)
        
        for tag in tagsToRemove {
            note.removeFromTags(tag)
        }
        for tag in tagsToAdd {
            note.addToTags(tag)
        }
        
        note.syncStatus = 1
        note.updatedAt = Date()
        
        TodoSyncService.shared.syncTodos(for: note, in: viewContext)
        
        saveContext()
        
        self.lastLoadedTitle = self.title
        self.lastLoadedContent = self.content
        self.lastLoadedTranscript = self.transcript
        
        Task {
            await SyncEngine.shared.sync()
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save note: \(error.localizedDescription)")
        }
    }
    
    private var hasPendingTextEdits: Bool {
        title != lastLoadedTitle || content != lastLoadedContent || transcript != lastLoadedTranscript
    }
    
    private func hasAnyEditableChanges() -> Bool {
        let noteTitle = note.title ?? ""
        let noteContent = note.content ?? ""
        let noteTranscript = note.transcript ?? ""
        let noteTags = note.tags as? Set<Tag> ?? []
        let noteImages = note.allImageData
        
        if title != noteTitle { return true }
        if content != noteContent { return true }
        if note.hasAudio && transcript != noteTranscript { return true }
        if tags != noteTags { return true }
        if workingImages != noteImages { return true }
        if format != note.formatEnum { return true }
        
        return false
    }
    
    private func observeManagedObjectChanges() {
        NotificationCenter.default.publisher(
            for: .NSManagedObjectContextObjectsDidChange,
            object: viewContext
        )
        .sink { [weak self] notification in
            guard let self = self else { return }
            
            let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
            let refreshed = notification.userInfo?[NSRefreshedObjectsKey] as? Set<NSManagedObject> ?? []
            let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
            let candidates = updated.union(refreshed).union(inserted)
            
            let noteChanged = candidates.contains(where: { $0.objectID == self.note.objectID })
            guard noteChanged else { return }
            
            guard !self.hasPendingTextEdits else { return }

            DispatchQueue.main.async {
                self.refresh()
            }
        }
        .store(in: &cancellables)
    }
}
