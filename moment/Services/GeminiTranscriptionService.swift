//
//  GeminiTranscriptionService.swift
//  moment
//
//  Created by wen li on 2026/1/25.
//

import Foundation
import AVFoundation
import Combine

#if canImport(GoogleGenerativeAI)
import GoogleGenerativeAI
#endif

@MainActor
class GeminiTranscriptionService: ObservableObject {
    static let shared = GeminiTranscriptionService()
    
    @Published var isTranscribing = false
    @Published var errorMessage: String?
    
    private init() {}
    
    func transcribeAudio(url: URL) async -> String? {
        let result = await transcribeAudioWithSegments(url: url)
        return result?.text
    }
    
    /// Transcribes audio using Gemini and returns both the full text and timestamped segments
    func transcribeAudioWithSegments(url: URL) async -> (text: String, segments: [TranscriptSegment])? {
        #if canImport(GoogleGenerativeAI)
        guard Secrets.geminiAPIKey != "YOUR_API_KEY_HERE" else {
            errorMessage = "Please set your Gemini API Key in Secrets.swift"
            return nil
        }
        
        isTranscribing = true
        errorMessage = nil
        
        do {
            let model = GenerativeModel(
                name: "gemini-1.5-flash",
                apiKey: Secrets.geminiAPIKey
            )
            
            let audioData = try Data(contentsOf: url)
            
            // Request JSON array with timestamps for highlight support
            let prompt = """
            Transcribe this audio file accurately. Return ONLY a JSON array of segments with no markdown, no extra text.
            Each segment should cover roughly one sentence or phrase.
            Format: [{"text": "...", "start": 0.0, "end": 2.5}, ...]
            Use seconds for start/end times. If timing is unknown, estimate proportionally based on total audio length.
            """
            
            let response = try await model.generateContent(
                prompt,
                ModelContent.Part.data(mimetype: "audio/m4a", data: audioData)
            )
            
            isTranscribing = false
            
            guard let rawText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }
            
            // Attempt to parse JSON segments
            if let jsonData = rawText.data(using: .utf8) {
                struct GeminiSegment: Codable {
                    let text: String
                    let start: Double
                    let end: Double
                }
                if let geminiSegments = try? JSONDecoder().decode([GeminiSegment].self, from: jsonData) {
                    let segments = geminiSegments.map {
                        TranscriptSegment(text: $0.text, startTime: $0.start, endTime: $0.end)
                    }
                    let fullText = geminiSegments.map { $0.text }.joined(separator: " ")
                    return (fullText, segments)
                }
            }
            
            // Fallback: return plain text with no segments
            return (rawText, [])
            
        } catch {
            print("Gemini Transcription Error: \(error)")
            errorMessage = "Gemini Error: \(error.localizedDescription)"
            isTranscribing = false
            return nil
        }
        #else
        errorMessage = "GoogleGenerativeAI SDK not found. Please add the package."
        print("Error: GoogleGenerativeAI SDK is missing.")
        return nil
        #endif
    }
}
