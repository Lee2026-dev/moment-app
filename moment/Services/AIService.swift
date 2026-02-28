//
//  AIService.swift
//  moment
//
//  Created by wen li on 2026/2/9.
//

import Foundation
import Combine

struct SummarizeRequest: Encodable {
    let text: String
    let format: String
}

struct SummarizeResponse: Decodable {
    let summary: String
    let suggested_title: String
}

@MainActor
class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var isSummarizing = false
    @Published private(set) var summarizingNoteIDs: Set<UUID> = []
    @Published var errorMessage: String?
    
    private var inFlightCount: Int = 0
    
    private init() {}
    
    func isSummarizing(noteID: UUID?) -> Bool {
        guard let noteID else { return false }
        return summarizingNoteIDs.contains(noteID)
    }
    
    /// Summarize transcript text via the backend `/ai/summarize` endpoint.
    /// Returns a tuple of (summary, suggestedTitle).
    func summarize(
        text: String,
        format: NoteFormat = .daily,
        noteID: UUID? = nil
    ) async throws -> (summary: String, suggestedTitle: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.emptyInput
        }
        
        inFlightCount += 1
        isSummarizing = true
        if let noteID {
            summarizingNoteIDs.insert(noteID)
        }
        errorMessage = nil
        
        defer {
            inFlightCount = max(0, inFlightCount - 1)
            if let noteID {
                summarizingNoteIDs.remove(noteID)
            }
            isSummarizing = inFlightCount > 0
        }
        
        do {
            let request = SummarizeRequest(text: text, format: format.rawValue)
            let response: SummarizeResponse = try await APIService.shared.request(
                "/ai/summarize",
                method: "POST",
                body: request
            )
            return (summary: response.summary, suggestedTitle: response.suggested_title)
        } catch {
            let message: String
            if let apiError = error as? APIError {
                switch apiError {
                case .unauthorized:
                    message = "Please sign in to use AI features."
                case .serverError(let statusCode, _):
                    message = "Server error (\(statusCode)). Please try again."
                case .networkError:
                    message = "Network error. Please check your connection."
                default:
                    message = "Failed to generate summary."
                }
            } else {
                message = error.localizedDescription
            }
            errorMessage = message
            throw error
        }
    }
}

enum AIServiceError: LocalizedError {
    case emptyInput
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "No transcript text to summarize."
        }
    }
}
