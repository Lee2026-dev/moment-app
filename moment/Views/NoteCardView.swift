//
//  NoteCardView.swift
//  moment
//
//  Created by Antigravity on 2026/1/20.
//

import SwiftUI
import CoreData

struct NoteCardView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var aiService = AIService.shared
    @ObservedObject var note: Note
    @Environment(\.colorScheme) var colorScheme
    @State private var parentTitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Icon + Date
            HStack {
                if note.hasAudio {
                    if note.isFollowUp {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 12))
                            .foregroundColor(MomentDesign.Colors.accent)
                        Text("FOLLOW-UP")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(MomentDesign.Colors.accent)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 12))
                            .foregroundColor(MomentDesign.Colors.accent)
                    }
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(formatDateLabel(note.safeTimestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                if isSummarizingThisNote {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(MomentDesign.Colors.accent)
                        .accessibilityLabel("Summarizing")
                        .padding(.leading, 6)
                }
                
                // Format Icon
                Image(systemName: note.formatEnum.icon)
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.leading, 4)
            }

            // Title
            Text(note.displayTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(MomentDesign.Colors.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            if note.isFollowUp, let parentTitle, !parentTitle.isEmpty {
                Text("Following: \(parentTitle)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MomentDesign.Colors.accent.opacity(0.9))
                    .lineLimit(1)
            }

            // Content Preview
            Text(note.contentPreview)
                .font(.system(size: 13))
                .foregroundColor(MomentDesign.Colors.textSecondary)
                .lineLimit(3)
                .lineSpacing(1)
            
            // Image/Indicator if present
            let allImages = note.allImageData
            if !allImages.isEmpty {
                ImageCardThumbnails(images: allImages)
                    .padding(.top, 4)
            } else if note.hasAudio {
                HStack(spacing: 4) {
                    ForEach(0..<6) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(MomentDesign.Colors.accent.opacity(0.6))
                            .frame(width: 2, height: CGFloat.random(in: 4...12))
                    }
                }
                .padding(.top, 8)
            }
            
            Spacer(minLength: 4)
            
            // Favorite Toggle (Bottom Right)
//            HStack {
//                Spacer()
//                Button(action: {
//                    NoteService.shared.toggleFavorite(note, in: note.managedObjectContext ?? PersistenceController.shared.container.viewContext)
//                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                }) {
//                    Image(systemName: note.isFavorite ? "heart.fill" : "heart")
//                        .font(.system(size: 18))
//                        .foregroundColor(note.isFavorite ? .red : .gray.opacity(0.5))
//                        .padding(8)
//                        .background(Color.white.opacity(0.1))
//                        .clipShape(Circle())
//                }
//            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(minHeight: note.hasImages ? 180 : 100, alignment: .top)
        .background(MomentDesign.Colors.surface)
        .cornerRadius(20)
        .shadow(color: MomentDesign.Colors.shadow.opacity(0.05), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(MomentDesign.Colors.border.opacity(0.5), lineWidth: 0.5)
        )
        .onAppear {
            loadParentTitleIfNeeded()
        }
        .onChange(of: note.parentNoteID) {
            loadParentTitleIfNeeded()
        }
    }
    
    private var isSummarizingThisNote: Bool {
        if aiService.isSummarizing(noteID: note.id) { return true }
        
        let transcript = note.displayTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = (note.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let isWithinWindow = note.safeTimestamp >= Date().addingTimeInterval(-120)
        
        return note.hasAudio && isWithinWindow && !transcript.isEmpty && content.isEmpty
    }

    private static let todayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    private static let defaultFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private func formatDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return Self.todayFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.defaultFormatter.string(from: date)
        }
    }
    
    private func loadParentTitleIfNeeded() {
        guard note.isFollowUp,
              let parentID = note.parentNoteID,
              let context = note.managedObjectContext else {
            parentTitle = nil
            return
        }
        
        parentTitle = NoteService.shared.fetchNote(withID: parentID, in: context)?.displayTitle
    }
}
