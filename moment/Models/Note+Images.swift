//
//  Note+Images.swift
//  moment
//
//  Multi-image support extensions for Note entity
//

import Foundation
import CoreData

extension Note {
    
    // MARK: - Image Relationship Helpers
    
    /// Returns images sorted by sortIndex
    var orderedImages: [NoteImage] {
        let imageSet = images as? Set<NoteImage> ?? []
        return imageSet.sorted { $0.sortIndex < $1.sortIndex }
    }
    
    /// All image data as an array (for UI binding)
    var imageDataArray: [Data] {
        orderedImages.compactMap { $0.imageData }
    }
    
    /// Whether the note has any images (new or legacy)
    var hasImages: Bool {
        (images?.count ?? 0) > 0 || imageData != nil
    }
    
    /// First image data (for thumbnails and backward compatibility)
    var firstImageData: Data? {
        orderedImages.first?.imageData ?? imageData
    }
    
    /// Total number of images
    var imageCount: Int {
        let newCount = images?.count ?? 0
        if newCount > 0 {
            return newCount
        }
        return imageData != nil ? 1 : 0
    }
    
    /// Get all images including legacy single image
    /// Use this for display to ensure backward compatibility
    var allImageData: [Data] {
        let newImages = imageDataArray
        if !newImages.isEmpty {
            return newImages
        }
        // Fallback to legacy single image
        if let legacyData = imageData {
            return [legacyData]
        }
        return []
    }
}
