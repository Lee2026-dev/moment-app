//
//  NoteService.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import Foundation
import CoreData

/// Service for managing Note entities in Core Data
class NoteService {
    static let shared = NoteService()
    
    private init() {}
    
    /// Creates a new note with audio and transcription
    /// - Parameters:
    ///   - noteID: The UUID for the note (should match the audio file ID)
    ///   - audioURL: The URL of the audio file
    ///   - transcribedText: The transcribed text (optional)
    ///   - title: Optional title for the note
    ///   - imageData: Optional image data (compressed)
    ///   - parentNoteID: Optional parent note ID when creating a follow-up note
    ///   - context: The Core Data managed object context
    /// - Returns: The created Note entity, or nil if creation failed
    @discardableResult
    func createNote(
        withID noteID: UUID,
        audioURL: URL?,
        transcribedText: String?,
        title: String? = nil,
        imageData: Data? = nil,
        format: NoteFormat = .daily,
        parentNoteID: UUID? = nil,
        in context: NSManagedObjectContext
    ) -> Note? {
        let normalizedParentNoteID: UUID?
        if let parentNoteID {
            // Keep follow-ups anchored to the root voice note for stable thread rendering.
            normalizedParentNoteID = resolveThreadParentNoteID(from: parentNoteID, in: context)
        } else {
            normalizedParentNoteID = nil
        }
        
        let note = Note(context: context)
        note.id = noteID
        note.timestamp = Date()
        note.updatedAt = Date()
        note.isFavorite = false
        note.syncStatus = 1 // 1 = Pending
        note.formatEnum = format
        note.parentNoteID = normalizedParentNoteID
        
        // Bind to current user
        if let currentUserId = AuthenticationService.shared.currentUser?.id {
            note.userId = currentUserId
        }
        
        // Set title - use provided title, or generate from content, or use default
        if let title = title, !title.isEmpty {
            note.title = title
        } else if let content = transcribedText, !content.isEmpty {
            // Use first line or first 50 characters as title
            let firstLine = content.components(separatedBy: .newlines).first ?? ""
            note.title = firstLine.count > 50 ? String(firstLine.prefix(50)) + "..." : firstLine
        } else {
            // Default title based on note type
            note.title = audioURL != nil ? "Voice Note" : "Note"
        }
        
        // Set content from transcription (for voice notes) or leave empty (for text notes)
        // Record both content and transcript separately
        
        // Fix: Do NOT copy transcript to content for voice notes. Content should start empty.
        if audioURL == nil {
            note.content = transcribedText
        } else {
            note.content = "" // Voice notes start with empty content for user notes
        }
        
        note.transcript = transcribedText
        
        // Set audio URL - store just the filename relative to Documents/Audio/
        if let audioURL = audioURL {
            // Extract just the filename (e.g., "UUID.m4a")
            let filename = audioURL.lastPathComponent
            note.audioURL = filename
        }
        
        // Set transcription status
        if let transcribedText = transcribedText, !transcribedText.isEmpty {
            note.transcriptionStatus = "completed"
        } else if audioURL != nil {
            note.transcriptionStatus = "failed"
        } else {
            note.transcriptionStatus = nil
        }
        
        // Set image data
        note.imageData = imageData
        
        // Explicitly mark as pending sync
        note.syncStatus = 1 // 1 = Pending
        
        // Save the context
        do {
            try context.save()
            print("Note created successfully with ID: \(noteID.uuidString)")
            
            return note
        } catch {
            print("Failed to save note: \(error.localizedDescription)")
            context.rollback()
            return nil
        }
    }
    
    /// Deletes a note and its associated audio file
    /// - Parameters:
    ///   - note: The note to delete
    ///   - context: The Core Data managed object context
    func deleteNote(_ note: Note, in context: NSManagedObjectContext) {
        // Delete associated audio file if it exists
        if let noteID = note.id {
            AudioFileManager.shared.deleteAudioFile(for: noteID)
        }
        
        // Delete the note from Core Data
        context.delete(note)
        
        do {
            try context.save()
            print("Note deleted successfully")
        } catch {
            print("Failed to delete note: \(error.localizedDescription)")
            context.rollback()
        }
    }
    
    /// Gets the full audio URL for a note
    /// - Parameter note: The note entity
    /// - Returns: The full URL to the audio file, or nil if not found
    func getAudioURL(for note: Note) -> URL? {
        guard let noteID = note.id else { return nil }
        return AudioFileManager.shared.audioURL(for: noteID)
    }
    
    /// Fetches a note by its ID
    /// - Parameters:
    ///   - noteID: Note UUID
    ///   - context: The Core Data managed object context
    /// - Returns: The matching note if found
    func fetchNote(withID noteID: UUID, in context: NSManagedObjectContext) -> Note? {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND deletedAt == nil", noteID as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch note by ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Resolves the root parent note ID for follow-up threads.
    /// If a follow-up note is passed as the parent, this walks upward until the top-most note.
    /// - Parameters:
    ///   - candidateParentID: The selected parent note UUID
    ///   - context: The Core Data managed object context
    /// - Returns: Root parent note UUID used to anchor the thread
    func resolveThreadParentNoteID(from candidateParentID: UUID, in context: NSManagedObjectContext) -> UUID {
        var currentParentID = candidateParentID
        var resolvedParentID = candidateParentID
        var visitedIDs = Set<UUID>()
        
        while !visitedIDs.contains(currentParentID),
              let currentParent = fetchNote(withID: currentParentID, in: context) {
            resolvedParentID = currentParentID
            guard let nextParentID = currentParent.parentNoteID else {
                break
            }
            visitedIDs.insert(currentParentID)
            currentParentID = nextParentID
        }
        
        return resolvedParentID
    }
    
    /// Fetches follow-up notes linked to a parent note
    /// - Parameters:
    ///   - parentNoteID: Parent note UUID
    ///   - limit: Max number of results
    ///   - context: The Core Data managed object context
    /// - Returns: Follow-up notes sorted newest first
    func fetchFollowUpNotes(for parentNoteID: UUID, limit: Int = 8, in context: NSManagedObjectContext) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "parentNoteID == %@ AND deletedAt == nil", parentNoteID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.timestamp, ascending: false)]
        request.fetchLimit = max(1, limit)
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch follow-up notes: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetches all follow-up notes in a thread
    /// - Parameters:
    ///   - parentNoteID: Parent note UUID
    ///   - context: The Core Data managed object context
    /// - Returns: Follow-up notes sorted oldest first for timeline display
    func fetchThreadNotes(parentNoteID: UUID, in context: NSManagedObjectContext) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "parentNoteID == %@ AND deletedAt == nil", parentNoteID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.timestamp, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch thread notes: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Toggles the favorite status of a note
    /// - Parameters:
    ///   - note: The note to toggle
    ///   - context: The Core Data managed object context
    func toggleFavorite(_ note: Note, in context: NSManagedObjectContext) {
        context.perform {
            note.isFavorite.toggle()
            note.syncStatus = 1 // 1 = Pending
            do {
                try context.save()
                print("Note favorite status toggled: \(note.isFavorite)")
                Task { await SyncEngine.shared.sync() }
            } catch {
                print("Failed to toggle favorite: \(error.localizedDescription)")
                context.rollback()
            }
        }
    }
    // MARK: - Tag Management
    
    /// Creates a new tag or returns existing one with same name
    func createTag(name: String, color: String? = nil, in context: NSManagedObjectContext) -> Tag {
        // Check if tag already exists
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        
        do {
            let results = try context.fetch(request)
            if let existingTag = results.first {
                return existingTag
            }
        } catch {
            print("Error checking for existing tag: \(error)")
        }
        
        // Create new tag
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.color = color
        tag.createdAt = Date()
        tag.syncStatus = 1
        
        // Bind to current user
        if let currentUserId = AuthenticationService.shared.currentUser?.id {
            tag.userId = currentUserId
        }
        
        do {
            try context.save()
            Task { await SyncEngine.shared.sync() }
        } catch {
            print("Failed to save tag: \(error)")
            context.rollback()
        }
        
        return tag
    }
    
    /// Fetches all tags sorted by name
    func fetchTags(in context: NSManagedObjectContext) -> [Tag] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch tags: \(error)")
            return []
        }
    }
    
    /// Searches tags matching the query
    func searchTags(query: String, in context: NSManagedObjectContext) -> [Tag] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to search tags: \(error)")
            return []
        }
    }
    
    /// Deletes a tag
    func deleteTag(_ tag: Tag, in context: NSManagedObjectContext) {
        context.delete(tag)
        do {
            try context.save()
        } catch {
            print("Failed to delete tag: \(error)")
            context.rollback()
        }
    }
    
    /// Adds a tag to a note
    func addTag(_ tag: Tag, to note: Note, in context: NSManagedObjectContext) {
        note.addToTags(tag)
        do {
            try context.save()
        } catch {
            print("Failed to add tag to note: \(error)")
            context.rollback()
        }
    }
    
    /// Removes a tag from a note
    func removeTag(_ tag: Tag, from note: Note, in context: NSManagedObjectContext) {
        note.removeFromTags(tag)
        do {
            try context.save()
        } catch {
            print("Failed to remove tag from note: \(error)")
            context.rollback()
        }
    }
    
    // MARK: - Multi-Image Management
    
    /// Creates a new note with multiple images
    /// - Parameters:
    ///   - noteID: The UUID for the note
    ///   - audioURL: Optional audio file URL
    ///   - transcribedText: Optional transcribed text
    ///   - title: Optional title
    ///   - images: Array of processed image data
    ///   - parentNoteID: Optional parent note ID when creating a follow-up note
    ///   - context: The Core Data managed object context
    /// - Returns: The created Note entity, or nil if creation failed
    @discardableResult
    func createNote(
        withID noteID: UUID,
        audioURL: URL?,
        transcribedText: String?,
        title: String? = nil,
        images: [Data],
        format: NoteFormat = .daily,
        parentNoteID: UUID? = nil,
        in context: NSManagedObjectContext
    ) -> Note? {
        // Create the base note without images first
        guard let note = createNote(
            withID: noteID,
            audioURL: audioURL,
            transcribedText: transcribedText,
            title: title,
            imageData: nil,
            format: format,
            parentNoteID: parentNoteID,
            in: context
        ) else {
            return nil
        }
        
        // Add images to the note
        if !images.isEmpty {
            addImages(images, to: note, in: context)
        }
        
        return note
    }
    
    /// Adds multiple images to a note
    /// - Parameters:
    ///   - imagesData: Array of image data to add
    ///   - note: The note to add images to
    ///   - context: The Core Data managed object context
    func addImages(_ imagesData: [Data], to note: Note, in context: NSManagedObjectContext) {
        let startIndex = Int16(note.images?.count ?? 0)
        
        for (index, data) in imagesData.enumerated() {
            let image = NoteImage(context: context)
            image.id = UUID()
            image.imageData = data
            image.sortIndex = startIndex + Int16(index)
            image.createdAt = Date()
            image.parentNote = note
        }
        
        do {
            try context.save()
            print("Added \(imagesData.count) images to note: \(note.id?.uuidString ?? "unknown")")
        } catch {
            print("Failed to add images: \(error.localizedDescription)")
            context.rollback()
        }
    }
    
    /// Removes a single image from a note
    /// - Parameters:
    ///   - image: The NoteImage to remove
    ///   - context: The Core Data managed object context
    func removeImage(_ image: NoteImage, in context: NSManagedObjectContext) {
        context.delete(image)
        
        do {
            try context.save()
            print("Removed image successfully")
        } catch {
            print("Failed to remove image: \(error.localizedDescription)")
            context.rollback()
        }
    }
    
    /// Removes an image at a specific index from a note
    /// - Parameters:
    ///   - index: The index of the image to remove
    ///   - note: The note containing the image
    ///   - context: The Core Data managed object context
    func removeImage(at index: Int, from note: Note, in context: NSManagedObjectContext) {
        let orderedImages = note.orderedImages
        guard index >= 0 && index < orderedImages.count else { return }
        
        let imageToRemove = orderedImages[index]
        removeImage(imageToRemove, in: context)
        
        // Reindex remaining images
        reindexImages(for: note, in: context)
    }
    
    /// Reorders images for a note
    /// - Parameters:
    ///   - orderedImages: The images in their new order
    ///   - context: The Core Data managed object context
    func reorderImages(_ orderedImages: [NoteImage], in context: NSManagedObjectContext) {
        for (index, image) in orderedImages.enumerated() {
            image.sortIndex = Int16(index)
        }
        
        do {
            try context.save()
            print("Reordered \(orderedImages.count) images")
        } catch {
            print("Failed to reorder images: \(error.localizedDescription)")
            context.rollback()
        }
    }
    
    /// Reindexes all images for a note (after deletion)
    /// - Parameters:
    ///   - note: The note to reindex images for
    ///   - context: The Core Data managed object context
    private func reindexImages(for note: Note, in context: NSManagedObjectContext) {
        let orderedImages = note.orderedImages
        for (index, image) in orderedImages.enumerated() {
            image.sortIndex = Int16(index)
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to reindex images: \(error.localizedDescription)")
            context.rollback()
        }
    }
    
    /// Replaces all images for a note
    /// - Parameters:
    ///   - imagesData: New array of image data
    ///   - note: The note to update
    ///   - context: The Core Data managed object context
    func replaceImages(_ imagesData: [Data], for note: Note, in context: NSManagedObjectContext) {
        // Remove all existing images
        if let existingImages = note.images as? Set<NoteImage> {
            for image in existingImages {
                context.delete(image)
            }
        }
        
        // Also clear legacy imageData
        note.imageData = nil
        
        // Add new images
        for (index, data) in imagesData.enumerated() {
            let image = NoteImage(context: context)
            image.id = UUID()
            image.imageData = data
            image.sortIndex = Int16(index)
            image.createdAt = Date()
            image.parentNote = note
        }
        
        do {
            try context.save()
            print("Replaced images for note: \(note.id?.uuidString ?? "unknown")")
        } catch {
            print("Failed to replace images: \(error.localizedDescription)")
            context.rollback()
        }
    }
}
