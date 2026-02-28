//
//  Note+Migration.swift
//  moment
//
//  Migration logic for legacy single-image notes
//

import Foundation
import CoreData

extension Note {
    
    /// Migrates legacy single imageData to the new NoteImage relationship
    /// Call this once on app launch or when loading a note
    /// - Parameter context: The managed object context
    func migrateImageDataIfNeeded(in context: NSManagedObjectContext) {
        // Only migrate if we have legacy imageData and no new images
        guard let legacyData = self.imageData,
              (self.images?.count ?? 0) == 0 else {
            return
        }
        
        let image = NoteImage(context: context)
        image.id = UUID()
        image.imageData = legacyData
        image.sortIndex = 0
        image.createdAt = self.timestamp ?? Date()
        image.parentNote = self
        
        // Clear legacy data to avoid duplication
        // Note: We set it to nil after migration
        self.imageData = nil
        
        print("Migrated legacy imageData to NoteImage for note: \(self.id?.uuidString ?? "unknown")")
    }
}

// MARK: - Batch Migration Helper

extension NSManagedObjectContext {
    
    /// Migrates all legacy notes with single imageData to the new NoteImage model
    /// Call this once on app launch
    func migrateAllLegacyImages() {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "imageData != nil")
        
        do {
            let notesWithLegacyImages = try fetch(request)
            
            if notesWithLegacyImages.isEmpty {
                print("No legacy images to migrate")
                return
            }
            
            print("Migrating \(notesWithLegacyImages.count) notes with legacy images...")
            
            for note in notesWithLegacyImages {
                note.migrateImageDataIfNeeded(in: self)
            }
            
            try save()
            print("Legacy image migration completed successfully")
            
        } catch {
            print("Error during legacy image migration: \(error.localizedDescription)")
            rollback()
        }
    }
}
