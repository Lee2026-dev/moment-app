//
//  NoteListController.swift
//  moment
//
//  Created by wen li on 2026/1/13.
//

import Foundation
import CoreData
import SwiftUI
import Combine

class NoteListController: NSObject, ObservableObject {
    @Published var searchText = ""
    @Published var showingNoteTypeSelection = false
    @Published var showingCreateNote = false
    // @Published var showingAudioRecording = false
    
    // Image Note Flow
    @Published var showingImageSourceSelection = false
    @Published var showingImagePicker = false
    @Published var showingCameraPicker = false
    @Published var showingMediaPreparer = false
    @Published var preselectedImages: [Data] = []
    
    @Published var notes: [Note] = []
    
    enum SortOption: String, CaseIterable, Identifiable {
        case dateDesc = "Newest First"
        case dateAsc = "Oldest First"
        case titleAsc = "Title (A-Z)"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .dateDesc: return "arrow.down"
            case .dateAsc: return "arrow.up"
            case .titleAsc: return "textformat"
            }
        }
    }
    
    @Published var sortOption: SortOption = .dateDesc {
        didSet {
            updateSortOrder()
        }
    }
    
    internal let viewContext: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<Note>
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.timestamp, ascending: false)]
        
        self.fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        super.init()
        self.fetchedResultsController.delegate = self
        
        performFetch()
    }
    
    private func performFetch() {
        do {
            try fetchedResultsController.performFetch()
            self.notes = fetchedResultsController.fetchedObjects ?? []
        } catch {
            print("Failed to fetch notes: \(error)")
        }
    }
    
    private func updateSortOrder() {
        let request = fetchedResultsController.fetchRequest
        
        switch sortOption {
        case .dateDesc:
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.timestamp, ascending: false)]
        case .dateAsc:
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.timestamp, ascending: true)]
        case .titleAsc:
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.title, ascending: true)]
        }
        
        performFetch()
    }
    
    @Published var selectedTags: Set<Tag> = []
    
    var filteredNotes: [Note] {
        var result = notes
        
        // Filter by text
        if !searchText.isEmpty {
            result = result.filter { note in
                let titleMatch = note.displayTitle.localizedCaseInsensitiveContains(searchText)
                let contentMatch = (note.content ?? "").localizedCaseInsensitiveContains(searchText)
                return titleMatch || contentMatch
            }
        }
        
        // Filter by tags
        if !selectedTags.isEmpty {
            result = result.filter { note in
                let noteTags = note.tags as? Set<Tag> ?? []
                return selectedTags.isSubset(of: noteTags)
            }
        }
        
        return result
    }
    
    func deleteNote(_ note: Note) {
        NoteService.shared.deleteNote(note, in: viewContext)
    }
    
    func formatDateForTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 H:mm"
        return formatter.string(from: date)
    }
    
    /*
    func handleAudioRecording(audioURL: URL?, noteID: UUID, transcribedText: String?, imageData: Data? = nil) {
        let title = "录音笔记 \(formatDateForTitle(Date()))"
        NoteService.shared.createNote(
            withID: noteID,
            audioURL: audioURL,
            transcribedText: transcribedText ?? "",
            title: title,
            imageData: imageData,
            in: viewContext
        )
    }
    */
}

extension NoteListController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let updatedNotes = controller.fetchedObjects as? [Note] {
            DispatchQueue.main.async {
                self.notes = updatedNotes
            }
        }
    }
}
