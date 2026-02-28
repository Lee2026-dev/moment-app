//
//  AudioFileManager.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import Foundation

/// Manages audio file storage and retrieval for voice notes
class AudioFileManager {
    static let shared = AudioFileManager()
    
    private let audioDirectoryName = "Audio"
    
    private init() {}
    
    /// Returns the URL for the audio directory in Documents
    private var audioDirectoryURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(audioDirectoryName)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: audioURL.path) {
            try? FileManager.default.createDirectory(at: audioURL, withIntermediateDirectories: true)
        }
        
        return audioURL
    }
    
    /// Creates a new unique audio file URL
    /// - Returns: A new URL for an audio file with a unique filename
    func createNewAudioURL() -> URL {
        let uniqueID = UUID()
        return audioDirectoryURL.appendingPathComponent("\(uniqueID.uuidString).m4a")
    }

    /// Returns the URL for an audio file given a note ID
    /// - Parameter noteID: The UUID of the note
    /// - Returns: URL for the audio file
    func audioURL(for noteID: UUID) -> URL {
        return audioDirectoryURL.appendingPathComponent("\(noteID.uuidString).m4a")
    }
    
    /// Checks if an audio file exists for a given note ID
    /// - Parameter noteID: The UUID of the note
    /// - Returns: True if the file exists
    func audioFileExists(for noteID: UUID) -> Bool {
        let url = audioURL(for: noteID)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Deletes the audio file for a given note ID
    /// - Parameter noteID: The UUID of the note
    /// - Returns: True if deletion was successful
    @discardableResult
    func deleteAudioFile(for noteID: UUID) -> Bool {
        let url = audioURL(for: noteID)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return true // File doesn't exist, consider it successful
        }
        
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("Error deleting audio file: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Gets the file size of an audio file
    /// - Parameter noteID: The UUID of the note
    /// - Returns: File size in bytes, or nil if file doesn't exist
    func audioFileSize(for noteID: UUID) -> Int64? {
        let url = audioURL(for: noteID)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            print("Error getting file size: \(error.localizedDescription)")
            return nil
        }
    }
}







