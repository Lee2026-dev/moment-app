//
//  NoteCreateController.swift
//  moment
//
//  Created by wen li on 2026/1/13.
//

import Foundation
import SwiftUI
import CoreData
import Combine


class NoteCreateController: ObservableObject {
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var tags: Set<Tag> = []
    @Published var selectedImages: [Data] = []
    @Published var format: NoteFormat = .daily
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    
    private let viewContext: NSManagedObjectContext
    private let onNoteCreated: (() -> Void)?
    
    init(viewContext: NSManagedObjectContext, initialImages: [Data] = [], onNoteCreated: (() -> Void)? = nil) {
        self.viewContext = viewContext
        self.selectedImages = initialImages
        self.onNoteCreated = onNoteCreated
    }
    
    convenience init(viewContext: NSManagedObjectContext, initialImage: Data?, onNoteCreated: (() -> Void)? = nil) {
        let images: [Data] = initialImage.map { [$0] } ?? []
        self.init(viewContext: viewContext, initialImages: images, onNoteCreated: onNoteCreated)
    }
    
    var hasContent: Bool {
        !title.isEmpty || !content.isEmpty || !selectedImages.isEmpty
    }
    
    func saveNote(dismiss: DismissAction) {
        guard hasContent else {
            errorMessage = "Please add a title, content, or image"
            showErrorAlert = true
            return
        }

        let processedImages = ImageHelper.shared.processImages(selectedImages)

        let noteID = UUID()
        
        var note: Note?
        if processedImages.isEmpty {
            note = NoteService.shared.createNote(
                withID: noteID,
                audioURL: nil,
                transcribedText: content.isEmpty ? nil : content,
                title: title.isEmpty ? nil : title,
                imageData: nil,
                format: format,
                in: viewContext
            )
        } else {
            note = NoteService.shared.createNote(
                withID: noteID,
                audioURL: nil,
                transcribedText: content.isEmpty ? nil : content,
                title: title.isEmpty ? nil : title,
                images: processedImages,
                format: format,
                in: viewContext
            )
        }

        if let note = note {
            for tag in tags {
                note.addToTags(tag)
            }
            
            if !content.isEmpty {
                note.content = content
                TodoSyncService.shared.syncTodos(for: note, in: viewContext)
                do {
                    try viewContext.save()
                } catch {
                    print("Failed to save note content: \(error.localizedDescription)")
                }
            }
            
            Task {
                await SyncEngine.shared.sync()
            }

            onNoteCreated?()
            dismiss()
        } else {
            errorMessage = "Failed to save note"
            showErrorAlert = true
        }
    }
    
    func addImage(_ data: Data) {
        guard selectedImages.count < 9 else { return }
        if let processed = ImageHelper.shared.processImageData(data) {
            selectedImages.append(processed)
            HapticHelper.light()
        }
    }
    
    func removeImage(at index: Int) {
        guard index >= 0 && index < selectedImages.count else { return }
        selectedImages.remove(at: index)
        HapticHelper.light()
    }
    
    var canAddMoreImages: Bool {
        selectedImages.count < 9
    }
    
    var remainingImageSlots: Int {
        9 - selectedImages.count
    }
}
