//
//  NoteListView.swift
//  moment
//
//  Created by wen li on 2026/1/1.
//

import SwiftUI
import CoreData

enum LayoutMode: String, CaseIterable {
    case list
    case grid
}


struct NoteListView: View {
    @StateObject private var controller: NoteListController
    @Environment(\.colorScheme) var colorScheme
    @State private var path = NavigationPath()
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("note_layout_mode") private var layoutMode: LayoutMode = .list
    
    // Deletion state
    @State private var noteToDelete: Note?
    @State private var showingDeleteConfirmation = false
    @State private var expandedThreadParentIDs: Set<UUID> = []
    
    init(context: NSManagedObjectContext) {
        _controller = StateObject(wrappedValue: NoteListController(context: context))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Background
                MomentDesign.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack(alignment: .center) {
                        Text("Notes")
                            .font(.system(size: 34, weight: .bold))
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            // Sort Menu
                            Menu {
                                Picker("Sort By", selection: $controller.sortOption) {
                                    ForEach(NoteListController.SortOption.allCases) { option in
                                        Label(option.rawValue, systemImage: option.icon)
                                            .tag(option)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(MomentDesign.Colors.primary)
                                    .frame(width: 36, height: 36)
                                    .background(MomentDesign.Colors.surfaceElevated)
                                    .clipShape(Circle())
                            }
                            
                            // Layout Toggle
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    layoutMode = layoutMode == .list ? .grid : .list
                                }
                                HapticHelper.medium()
                            }) {
                                Image(systemName: layoutMode == .list ? "square.grid.2x2" : "list.bullet")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(MomentDesign.Colors.primary)
                                    .frame(width: 36, height: 36)
                                    .background(MomentDesign.Colors.surfaceElevated)
                                    .clipShape(Circle())
                            }
                            
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 15)
                    
                    // Search Bar
                    MomentSearchField(text: $controller.searchText, placeholder: "Search notes, transcripts...")
                        .padding(.horizontal, 20)
                        
                    // Tag Filter Bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(NoteService.shared.fetchTags(in: controller.viewContext), id: \.id) { tag in
                                TagPill(
                                    tag: tag,
                                    isSelected: controller.selectedTags.contains(tag),
                                    isRemovable: false,
                                    onSelect: {
                                        if controller.selectedTags.contains(tag) {
                                            controller.selectedTags.remove(tag)
                                        } else {
                                            controller.selectedTags.insert(tag)
                                        }
                                        HapticHelper.light()
                                    },
                                    onRemove: nil
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .padding(.bottom, 8)

                    // Content
                    ScrollView {
                        VStack(spacing: 16) {
                            if controller.filteredNotes.isEmpty && controller.notes.isEmpty {
                                // Empty State
                                emptyStateView(icon: "note.text", title: "No Notes Yet", message: "Tap the + button to create your first note")
                            } else if controller.filteredNotes.isEmpty && !controller.searchText.isEmpty {
                                // No Results
                                emptyStateView(icon: "magnifyingglass", title: "No Results", message: "Try adjusting your search")
                            } else {
                                if layoutMode == .list {
                                    threadedListContent
                                } else {
                                    HStack(alignment: .top, spacing: 16) {
                                        let notes = visibleNotesForLayout
                                        let leftColumn = notes.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
                                        let rightColumn = notes.enumerated().filter { $0.offset % 2 != 0 }.map { $0.element }
                                        
                                        LazyVStack(spacing: 16) {
                                            ForEach(leftColumn, id: \.id) { note in
                                                noteCard(note: note)
                                            }
                                        }
                                        
                                        LazyVStack(spacing: 16) {
                                            ForEach(rightColumn, id: \.id) { note in
                                                noteCard(note: note)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            controller.showingNoteTypeSelection = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(MomentDesign.Colors.accent)
                                .clipShape(Circle())
                                .shadow(color: MomentDesign.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 90) // Above tab bar
                    }
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(path.isEmpty ? .visible : .hidden, for: .tabBar)
            .navigationDestination(for: Note.self) { note in
                NoteDetailView(note: note)
            }
            .sheet(isPresented: $controller.showingNoteTypeSelection) {
                NoteTypeSelectionView(onSelectText: {
                    controller.preselectedImages = []
                    controller.showingCreateNote = true
                }, onSelectAudio: {
                    controller.preselectedImages = []
                    Task {
                        await GlobalAudioService.shared.startRecording()
                    }
                }, onSelectImage: {
                    controller.preselectedImages = []
                    controller.showingImageSourceSelection = true
                })
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
            }
            .confirmationDialog("选择图片来源", isPresented: $controller.showingImageSourceSelection, titleVisibility: .visible) {
                Button("拍照") { controller.showingCameraPicker = true }
                Button("从相册选择") { controller.showingImagePicker = true }
                Button("取消", role: .cancel) { }
            }
            .sheet(isPresented: $controller.showingImagePicker) {
                MultiImagePicker(selectedImages: $controller.preselectedImages, maxCount: 9)
            }
            .fullScreenCover(isPresented: $controller.showingCameraPicker) {
                MultiCameraPicker(capturedImages: $controller.preselectedImages, maxCount: 9)
            }
            .fullScreenCover(isPresented: $controller.showingMediaPreparer) {
                if !controller.preselectedImages.isEmpty {
                    MediaNotePreparerView(
                        images: controller.preselectedImages,
                        onSelectText: {
                            controller.showingMediaPreparer = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                controller.showingCreateNote = true
                            }
                        },
                        onSelectAudio: {
                            let imagesForAudio = controller.preselectedImages
                            controller.preselectedImages = []
                            controller.showingMediaPreparer = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                Task {
                                    await GlobalAudioService.shared.startRecording(initialImages: imagesForAudio)
                                }
                            }
                        }
                    )
                    .environmentObject(themeManager)
                    .preferredColorScheme(themeManager.preferredColorScheme)
                }
            }
            .onChange(of: controller.preselectedImages) { newData in
                if !newData.isEmpty {
                    controller.showingMediaPreparer = true
                }
            }
            .onChange(of: controller.filteredNotes.compactMap(\.id)) { visibleIDs in
                let visibleSet = Set(visibleIDs)
                expandedThreadParentIDs = expandedThreadParentIDs.intersection(visibleSet)
            }
            .fullScreenCover(isPresented: $controller.showingCreateNote) {
                NoteCreateView(initialImages: controller.preselectedImages) {
                    controller.preselectedImages = []
                }
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
            }
            /*
            .fullScreenCover(isPresented: $controller.showingAudioRecording) {
                AudioRecordingView(initialImage: controller.preselectedImageData) { audioURL, noteID, transcribedText in
                    controller.handleAudioRecording(audioURL: audioURL, noteID: noteID, transcribedText: transcribedText, imageData: controller.preselectedImageData)
                    controller.preselectedImageData = nil
                }
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
            }
            */
            .alert("Delete Note", isPresented: $showingDeleteConfirmation, presenting: noteToDelete) { note in
                Button("Delete", role: .destructive) {
                    controller.deleteNote(note)
                    noteToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    noteToDelete = nil
                }
            } message: { note in
                Text("Are you sure you want to delete '\(note.displayTitle)'? This action cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func noteCard(note: Note) -> some View {
        NavigationLink(value: note) {
            NoteCardView(note: note)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                noteToDelete = note
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var topLevelNotesForThreadView: [Note] {
        let filtered = visibleNotesForLayout
        
        guard shouldShowFollowUps else {
            return filtered
        }
        
        let visibleIDs = Set(filtered.compactMap(\.id))
        
        return filtered.filter { note in
            guard note.isFollowUp, let parentID = note.parentNoteID else { return true }
            return !visibleIDs.contains(parentID)
        }
    }
    
    private var followUpsByParentID: [UUID: [Note]] {
        guard shouldShowFollowUps else { return [:] }
        
        let followUps = visibleNotesForLayout.filter { $0.isFollowUp && $0.parentNoteID != nil }
        return Dictionary(grouping: followUps, by: { $0.parentNoteID! })
            .mapValues { notes in
                notes.sorted { $0.safeTimestamp < $1.safeTimestamp }
            }
    }
    
    private var shouldShowFollowUps: Bool {
        !controller.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var visibleNotesForLayout: [Note] {
        let filtered = controller.filteredNotes
        if shouldShowFollowUps {
            return filtered
        }
        return filtered.filter { !$0.isFollowUp }
    }
    
    @ViewBuilder
    private var threadedListContent: some View {
        LazyVStack(spacing: 16) {
            ForEach(topLevelNotesForThreadView, id: \.objectID) { note in
                listRow(note: note, isFollowUpChild: false)
                
                if let noteID = note.id,
                   let followUps = followUpsByParentID[noteID],
                   !followUps.isEmpty {
                    threadToggleRow(parentID: noteID, followUpCount: followUps.count)
                    
                    if isThreadExpanded(parentID: noteID) {
                        ForEach(followUps, id: \.objectID) { followUp in
                            listRow(note: followUp, isFollowUpChild: true)
                        }
                    }
                }
            }
        }
    }
    
    private func isThreadExpanded(parentID: UUID) -> Bool {
        if !controller.searchText.isEmpty {
            return true
        }
        return expandedThreadParentIDs.contains(parentID)
    }
    
    @ViewBuilder
    private func threadToggleRow(parentID: UUID, followUpCount: Int) -> some View {
        let expanded = isThreadExpanded(parentID: parentID)
        
        HStack {
            Spacer()
            Button(action: {
                guard controller.searchText.isEmpty else { return }
                HapticHelper.light()
                if expandedThreadParentIDs.contains(parentID) {
                    expandedThreadParentIDs.remove(parentID)
                } else {
                    expandedThreadParentIDs.insert(parentID)
                }
            }) {
                HStack(spacing: 6) {
                    Text("\(followUpCount) follow-up\(followUpCount > 1 ? "s" : "")")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(MomentDesign.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(MomentDesign.Colors.surfaceElevated)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!controller.searchText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.top, -6)
        .padding(.bottom, -4)
    }
    
    @ViewBuilder
    private func listRow(note: Note, isFollowUpChild: Bool) -> some View {
        NavigationLink(value: note) {
            NoteRowView(note: note)
                .padding(.leading, isFollowUpChild ? 22 : 0)
                .overlay(alignment: .leading) {
                    if isFollowUpChild {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(MomentDesign.Colors.border.opacity(0.5))
                            .frame(width: 2, height: 48)
                            .padding(.leading, 8)
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                noteToDelete = note
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 100)
            ZStack {
                Circle()
                    .fill(MomentDesign.Colors.accent.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: icon)
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(MomentDesign.Colors.accent.opacity(0.6))
            }
            Text(title)
                .font(.system(size: 22, weight: .semibold))
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(MomentDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

struct NoteRowView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var aiService = AIService.shared
    @ObservedObject var note: Note
    @Environment(\.colorScheme) var colorScheme
    @State private var parentTitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Icon + Type + Date
            HStack(spacing: 8) {
                if note.hasAudio {
                    if note.isFollowUp {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 14))
                            .foregroundColor(MomentDesign.Colors.accent)
                        Text("VOICE FOLLOW-UP")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MomentDesign.Colors.accent)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14))
                            .foregroundColor(MomentDesign.Colors.accent)
                        Text("VOICE NOTE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MomentDesign.Colors.accent)
                    }
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text("TEXT NOTE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if note.hasAudio {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(MomentDesign.Colors.success)
                            .frame(width: 8, height: 8)
                        Text(formatDateLabel(note.safeTimestamp))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text(formatDateLabel(note.safeTimestamp))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                if isSummarizingThisNote {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(MomentDesign.Colors.accent)
                        .accessibilityLabel("Summarizing")
                        .padding(.leading, 6)
                }
                
                // Format Icon
                Image(systemName: note.formatEnum.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.leading, 4)
            }

            // Title
            Text(note.displayTitle)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(MomentDesign.Colors.text)
                .lineLimit(1)
            
            if note.isFollowUp, let parentTitle, !parentTitle.isEmpty {
                Text("Following: \(parentTitle)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(MomentDesign.Colors.accent.opacity(0.9))
                    .lineLimit(1)
            }

            // Content
            Text(note.contentPreview)
                .font(.system(size: 15))
                .foregroundColor(MomentDesign.Colors.textSecondary)
                .lineLimit(2)
                .lineSpacing(2)
            
            // Tags
            if !note.tagList.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(note.tagList, id: \.id) { tag in
                            Text("#" + (tag.name ?? ""))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(MomentDesign.Colors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(MomentDesign.Colors.surfaceElevated)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            // Image preview if available
            if let imageData = note.firstImageData {
                HStack(spacing: 8) {
                    ImageHelper.shared.image(from: imageData)?
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(MomentDesign.Colors.border.opacity(0.3), lineWidth: 0.5)
                        )
                    
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(MomentDesign.Colors.surface)
        .cornerRadius(24)
        .shadow(color: MomentDesign.Colors.shadow.opacity(0.05), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
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

struct NoteDetailView: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller: NoteDetailController
    @State private var summaryPollingTask: Task<Void, Never>?

    init(note: Note) {
        self.note = note
        _controller = StateObject(wrappedValue: NoteDetailController(
            note: note,
            viewContext: note.managedObjectContext ?? PersistenceController.shared.container.viewContext
        ))
    }

    var body: some View {
        NoteEditorEditView(
            noteID: controller.noteID,
            title: $controller.title,
            tags: $controller.tags,
            content: $controller.content,
            transcript: $controller.transcript,
            format: $controller.format,
            date: controller.timestamp,
            images: $controller.workingImages,
            audioURL: controller.audioFileURL,
            segments: controller.transcriptSegments,
            onSave: {
                controller.saveNote()
            },
            onCancel: { },
            showImagePicker: true,
            onSelectLinkedNote: { selectedNote in
                controller.switchToNote(selectedNote)
            }
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    persistBeforeLeaving()
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .foregroundColor(MomentDesign.Colors.primary)
            }
        }
        .onDisappear {
            summaryPollingTask?.cancel()
            summaryPollingTask = nil
            persistBeforeLeaving()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive || newPhase == .background {
                persistBeforeLeaving()
            }
        }
        .onAppear {
            controller.refresh()
            
            guard controller.hasAudio else { return }
            
            let initialContent = controller.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let initialTranscript = controller.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            let likelyPendingSummary = !initialTranscript.isEmpty && (initialContent.isEmpty || initialContent == initialTranscript)
            guard likelyPendingSummary else { return }
            
            summaryPollingTask?.cancel()
            summaryPollingTask = Task {
                let initialTitle = controller.title
                let deadline = Date().addingTimeInterval(120) // Avoid endless polling.
                
                while !Task.isCancelled {
                    await SyncEngine.shared.sync()
                    await MainActor.run {
                        controller.refreshIfNoPendingLocalEdits()
                    }
                    
                    let currentContent = await MainActor.run {
                        controller.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    let currentTitle = await MainActor.run { controller.title }
                    let currentTranscript = await MainActor.run {
                        controller.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    let summaryArrived = !currentContent.isEmpty &&
                        (currentContent != initialContent || currentTitle != initialTitle) &&
                        (currentContent != currentTranscript)
                    
                    if summaryArrived || Date() >= deadline {
                        break
                    }
                    
                    // High-frequency polling while waiting for summarize result.
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                
                await MainActor.run {
                    summaryPollingTask = nil
                }
            }
        }
    }
    
    private func persistBeforeLeaving() {
        controller.saveOrDeleteOnExit()
    }
}
