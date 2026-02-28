//
//  Note+Extensions.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import Foundation
import CoreData

extension Note {
    /// A non-optional computed property for timestamp
    /// Since Core Data generates optional properties even for required attributes,
    /// this provides a safe way to access timestamp without unwrapping
    var safeTimestamp: Date {
        return timestamp ?? Date()
    }
    
    /// A computed property for display title
    /// Returns the title if available, otherwise a default "Untitled" string
    var displayTitle: String {
        return title?.isEmpty == false ? title! : "Untitled"
    }
    
    /// A computed property for display transcript
    var displayTranscript: String {
        return transcript ?? ""
    }
    
    /// A computed property for display content preview
    /// Returns a truncated version of the content for list views
    var contentPreview: String {
        guard let content = content, !content.isEmpty else {
            return "No content"
        }
        return content.count > 100 ? String(content.prefix(100)) + "..." : content
    }
    
    /// Returns the full URL to the audio file for this note
    /// Uses AudioFileManager to ensure path consistency with the recorder
    var audioFileURL: URL? {
        guard let id = id else { return nil }
        
        // If we have an audioURL string (filename), we expect a file to exist matched by ID
        // We use the ID to resolve the path to ensure consistency with AudioRecordingView
        if audioURL != nil {
            return AudioFileManager.shared.audioURL(for: id)
        }
        
        return nil
    }
    
    /// Checks if this note has an audio file
    var hasAudio: Bool {
        guard let url = audioFileURL else { return false }
        // We defer to AudioFileManager to check existence implies we trust the ID mapping
        // But for performance in lists, checking file existence is okay
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Whether the note is a follow-up note linked to another note
    var isFollowUp: Bool {
        return parentNoteID != nil
    }
    
    /// Returns tags sorted by creation date
    var tagList: [Tag] {
        let set = tags as? Set<Tag> ?? []
        return set.sorted { $0.createdAt ?? Date() < $1.createdAt ?? Date() }
    }
    
    /// Helper for the format enum
    var formatEnum: NoteFormat {
        get { return NoteFormat(rawValue: (self.value(forKey: "format") as? String) ?? "daily") ?? .daily }
        set { self.setValue(newValue.rawValue, forKey: "format") }
    }
    
    /// Array of transcript segments parsed from the transcriptSegments JSON string
    var parsedTranscriptSegments: [TranscriptSegment] {
        guard let jsonString = self.value(forKey: "transcriptSegments") as? String,
              let data = jsonString.data(using: .utf8) else {
            return []
        }
        do {
            return try JSONDecoder().decode([TranscriptSegment].self, from: data)
        } catch {
            print("Error decoding transcript segments: \(error)")
            return []
        }
    }
    
    /// Helper to save transcript segments
    func setTranscriptSegments(_ segments: [TranscriptSegment]) {
        do {
            let data = try JSONEncoder().encode(segments)
            if let jsonString = String(data: data, encoding: .utf8) {
                self.setValue(jsonString, forKey: "transcriptSegments")
            }
        } catch {
            print("Error encoding transcript segments: \(error)")
        }
    }
}

/// Represents a segment of a transcript with timing information
struct TranscriptSegment: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    
    init(text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, startTime, endTime
    }
}

enum NoteFormat: String, CaseIterable, Identifiable {
    case daily
    case meeting
    case bulletpoint
    case todo
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .daily: return "Daily Journal"
        case .meeting: return "Meeting Minute"
        case .bulletpoint: return "Key Points"
        case .todo: return "Action Items"
        }
    }
    
    var icon: String {
        switch self {
        case .daily: return "book.fill"
        case .meeting: return "person.3.fill"
        case .bulletpoint: return "list.bullet.rectangle.portrait.fill"
        case .todo: return "checkmark.square.fill"
        }
    }
}
