//
//  NoteEditorView.swift
//  moment
//
//  Shared note editor component for both create and edit views
//

import SwiftUI
import CoreData
import PhotosUI
import Combine
import UIKit

// MARK: - Shared Note Subviews

class DynamicTextView: UITextView {
    var onLayout: (() -> Void)?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

enum EditorCommand: Equatable {
    case bullet
    case todo
    case h1
    case h2
    case setDeadline(Date)
    case removeDeadline
}

struct NoteToolbar: View {
    let showImagePicker: Bool
    @Binding var content: String
    @Binding var selectedItems: [PhotosPickerItem]
    let selectedImageCount: Int
    let maxImageCount: Int
    let isBulletActive: Bool
    let isTodoActive: Bool
    let isTodoChecked: Bool
    let isH1Active: Bool
    let isH2Active: Bool
    let hasDeadline: Bool
    let onCommand: (EditorCommand) -> Void
    let onShowDatePicker: () -> Void
    
    private var remainingSlots: Int {
        max(0, maxImageCount - selectedImageCount)
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Button(action: { onCommand(.h1) }) {
                    Text("H1")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(isH1Active ? MomentDesign.Colors.accent : MomentDesign.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(isH1Active ? MomentDesign.Colors.accent.opacity(0.1) : Color.clear)
                        .clipShape(Circle())
                }

                Button(action: { onCommand(.h2) }) {
                    Text("H2")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(isH2Active ? MomentDesign.Colors.accent : MomentDesign.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(isH2Active ? MomentDesign.Colors.accent.opacity(0.1) : Color.clear)
                        .clipShape(Circle())
                }

                Button(action: { onCommand(.bullet) }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isBulletActive ? MomentDesign.Colors.accent : MomentDesign.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(isBulletActive ? MomentDesign.Colors.accent.opacity(0.1) : Color.clear)
                        .clipShape(Circle())
                }

                Button(action: { onCommand(.todo) }) {
                    Image(systemName: isTodoChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isTodoActive || isTodoChecked ? MomentDesign.Colors.accent : MomentDesign.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(isTodoActive || isTodoChecked ? MomentDesign.Colors.accent.opacity(0.1) : Color.clear)
                        .clipShape(Circle())
                }
                
                // Deadline Button (Only for Todo items)
                if isTodoActive || isTodoChecked {
                    Button(action: { onShowDatePicker() }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(hasDeadline ? MomentDesign.Colors.accent : MomentDesign.Colors.primary)
                            .frame(width: 44, height: 44)
                            .background(hasDeadline ? MomentDesign.Colors.accent.opacity(0.1) : Color.clear)
                            .clipShape(Circle())
                    }
                }

                if showImagePicker && remainingSlots > 0 {
                    ZStack(alignment: .topTrailing) {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: remainingSlots,
                            matching: .images
                        ) {
                            Image(systemName: selectedImageCount > 0 ? "photo.fill" : "photo")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(selectedImageCount > 0 ? MomentDesign.Colors.accent : MomentDesign.Colors.primary)
                                .frame(width: 44, height: 44)
                        }
                        
                        if selectedImageCount > 0 {
                            Text("\(selectedImageCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(MomentDesign.Colors.accent)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassToolbar()
        }
        .padding(.bottom, 20)
    }
}

struct EditorContentView: View {
    @Binding var content: String
    @Binding var command: EditorCommand?
    @Binding var isBulletActive: Bool
    @Binding var isTodoActive: Bool
    @Binding var isTodoChecked: Bool
    @Binding var isH1Active: Bool
    @Binding var isH2Active: Bool
    @Binding var hasDeadline: Bool
    @Binding var currentDeadline: Date?
    var focusedField: FocusState<NoteEditorView.Field?>.Binding
    let images: [Data]
    var onTapImage: ((Int) -> Void)?
    var onDeleteImage: ((Int) -> Void)?
    
    @State private var isGalleryExpanded = false
    @State private var editorHeight: CGFloat = 150
    @Namespace private var animation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if content.isEmpty && focusedField.wrappedValue != .content {
                    Text("Start writing your thoughts...")
                        .font(.system(size: 18))
                        .foregroundColor(MomentDesign.Colors.textSecondary.opacity(0.5))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                }
                
                RichTextEditor(
                    text: $content,
                    dynamicHeight: $editorHeight,
                    command: $command,
                    isBulletActive: $isBulletActive,
                    isTodoActive: $isTodoActive,
                    isTodoChecked: $isTodoChecked,
                    isH1Active: $isH1Active,
                    isH2Active: $isH2Active,
                    hasDeadline: $hasDeadline,
                    currentDeadline: $currentDeadline,
                    isFocused: focusedField,
                    field: .content
                )
                .frame(minHeight: editorHeight)
                .focused(focusedField, equals: .content)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField.wrappedValue = .content
            }

            Spacer(minLength: 250)
        }
    }
}

struct TranscriptView: View {
    let transcript: String
    let audioURL: URL?
    let segments: [TranscriptSegment]
    
    @StateObject private var player = AudioPlayerController()
    
    private var activeSegmentID: UUID? {
        guard player.isPlaying || player.currentTime > 0 else { return nil }
        return segments.last(where: { $0.startTime <= player.currentTime })?.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let audioURL = audioURL {
                MiniAudioPlayerView(audioURL: audioURL, controller: player)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MomentDesign.Colors.accent)
                    Text("AI TRANSCRIPT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .kerning(1.2)
                        .foregroundColor(MomentDesign.Colors.accent.opacity(0.8))
                    Spacer()
                    Text("READ ONLY")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MomentDesign.Colors.accent.opacity(0.1))
                        .foregroundColor(MomentDesign.Colors.accent)
                        .cornerRadius(4)
                }
                
                // Transcript body — segmented if available, plain text otherwise
                if segments.isEmpty {
                    Text(transcript)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(MomentDesign.Colors.text.opacity(0.8))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ScrollViewReader { proxy in
                        segmentedTranscript(proxy: proxy)
                            .onChange(of: activeSegmentID) { newID in
                                guard let id = newID else { return }
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                    }
                }
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(MomentDesign.Colors.surfaceElevated)
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    MomentDesign.Colors.accent.opacity(0.05),
                                    MomentDesign.Colors.accent.opacity(0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(MomentDesign.Colors.accent.opacity(0.15), lineWidth: 1)
            )
            
            Spacer(minLength: 150)
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func segmentedTranscript(proxy: ScrollViewProxy) -> some View {
        // Flow-layout style: wrap segments as pills
        WrappingSegmentView(
            segments: segments,
            activeSegmentID: activeSegmentID,
            onTapSegment: { seg in
                player.seek(to: seg.startTime)
                if !player.isPlaying { player.play() }
            }
        )
    }
}

// MARK: - WrappingSegmentView
/// Renders transcript segments as clickable phrases in a scrollable vertical stack.
struct WrappingSegmentView: View {
    let segments: [TranscriptSegment]
    let activeSegmentID: UUID?
    let onTapSegment: (TranscriptSegment) -> Void
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(segments) { seg in
                SegmentPill(
                    segment: seg,
                    isActive: seg.id == activeSegmentID,
                    onTap: { onTapSegment(seg) }
                )
                .id(seg.id)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - SegmentPill
struct SegmentPill: View {
    let segment: TranscriptSegment
    let isActive: Bool
    let onTap: () -> Void
    
    /// Format seconds as m:ss  (e.g. 75.3 → "1:15")
    private func formatTime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            // Timestamp badge
            Text(formatTime(segment.startTime))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(
                    isActive
                        ? MomentDesign.Colors.accent
                        : MomentDesign.Colors.textSecondary
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(
                            isActive
                                ? MomentDesign.Colors.accent.opacity(0.12)
                                : MomentDesign.Colors.surface.opacity(0.6)
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: isActive)
            
            // Segment text
            Text(segment.text)
                .font(.system(size: 16, weight: isActive ? .semibold : .regular, design: .rounded))
                .foregroundColor(
                    isActive
                        ? MomentDesign.Colors.accent
                        : MomentDesign.Colors.text.opacity(0.70)
                )
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - NoteEditorView

struct NoteEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var themeManager: ThemeManager

    @Binding var title: String
    @Binding var tags: Set<Tag>
    @Binding var content: String
    @Binding var format: NoteFormat
    let date: Date?
    @Binding var images: [Data]
    let onSave: () -> Void
    let onCancel: () -> Void
    let showImagePicker: Bool
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @Environment(\.colorScheme) var colorScheme
    
    enum Field: Hashable {
        case title, content
    }
    @FocusState private var focusedField: Field?
    @State private var editorCommand: EditorCommand? = nil
    @State private var isBulletActive = false
    @State private var isTodoActive = false
    @State private var isTodoChecked = false
    @State private var isH1Active = false
    @State private var isH2Active = false
    @State private var hasDeadline = false
    @State private var currentDeadline: Date? = nil
    
    // Deadline State
    @State private var showingDatePicker = false
    @State private var selectedDeadline = Date()
    
    @State private var isGalleryExpanded = false
    @Namespace private var animation
    
    // Tag State
    @State private var showingTagSheet = false
    @State private var availableTags: [Tag] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            MomentDesign.Colors.background
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Date and Format Row
                        HStack {
                            Text(formatDate(date ?? Date()))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(MomentDesign.Colors.textSecondary)
                            
                            Spacer()
                            
                            // Format Selector
                            Menu {
                                Picker("Format", selection: $format) {
                                    ForEach(NoteFormat.allCases) { f in
                                        Label(f.displayName, systemImage: f.icon)
                                            .tag(f)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: format.icon)
                                        .font(.system(size: 12))
                                    Text(format.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(MomentDesign.Colors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(MomentDesign.Colors.surfaceElevated)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 24)

                        TextField("Title", text: $title)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(MomentDesign.Colors.text)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                            .focused($focusedField, equals: .title)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .content
                            }

                        // Tag Row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }), id: \.id) { tag in
                                    TagPill(tag: tag, isSelected: true, isRemovable: true, onSelect: nil) {
                                        tags.remove(tag)
                                        HapticHelper.light()
                                    }
                                }
                                
                                Button(action: {
                                    showingTagSheet = true
                                    HapticHelper.light()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("Tag")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                    }
                                    .foregroundColor(MomentDesign.Colors.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(MomentDesign.Colors.surfaceElevated)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(MomentDesign.Colors.border.opacity(0.5), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                        }

                        EditorContentView(
                            content: $content,
                            command: $editorCommand,
                            isBulletActive: $isBulletActive,
                            isTodoActive: $isTodoActive,
                            isTodoChecked: $isTodoChecked,
                            isH1Active: $isH1Active,
                            isH2Active: $isH2Active,
                            hasDeadline: $hasDeadline,
                            currentDeadline: $currentDeadline,
                            focusedField: $focusedField,
                            images: images,
                            onTapImage: nil,
                            onDeleteImage: { index in
                                if index >= 0 && index < images.count {
                                    images.remove(at: index)
                                }
                            }
                        )
                    }
                }
                .onTapGesture {
                    focusedField = .content
                }
            }
            
            // Toolbar Area - Only show when keyboard is active
            if focusedField != nil {
                NoteToolbar(
                    showImagePicker: showImagePicker,
                    content: $content,
                    selectedItems: $selectedItems,
                    selectedImageCount: images.count,
                    maxImageCount: 9,
                    isBulletActive: isBulletActive,
                    isTodoActive: isTodoActive,
                    isTodoChecked: isTodoChecked,
                    isH1Active: isH1Active,
                    isH2Active: isH2Active,
                    hasDeadline: hasDeadline,
                    onCommand: { command in
                        editorCommand = command
                        HapticHelper.light()
                    },
                    onShowDatePicker: {
                        selectedDeadline = currentDeadline ?? Date()
                        showingDatePicker = true
                        HapticHelper.light()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10) // Ensure toolbar is above gallery
            }
            
            // Floating Gallery Overlay
            FloatingGalleryOverlay(
                images: $images,
                isExpanded: $isGalleryExpanded,
                namespace: animation,
                onTapImage: nil,
                onDeleteImage: { index in
                    if index >= 0 && index < images.count {
                        images.remove(at: index)
                    }
                },
                bottomOffset: focusedField != nil ? 60 : 0 // Rough height of toolbar
            )
            .zIndex(100) // Topmost layer
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: focusedField)
        .onChange(of: selectedItems) {
            Task {
                for item in selectedItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            if let processed = ImageHelper.shared.processImageData(data) {
                                if images.count < 9 {
                                    images.append(processed)
                                }
                            }
                        }
                    }
                }
                await MainActor.run {
                    selectedItems = []
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            VStack {
                DatePicker("Deadline", selection: $selectedDeadline, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                
                HStack {
                    Button("Remove") {
                        editorCommand = .removeDeadline
                        showingDatePicker = false
                        HapticHelper.medium()
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Done") {
                        editorCommand = .setDeadline(selectedDeadline)
                        showingDatePicker = false
                        HapticHelper.success()
                    }
                    .fontWeight(.bold)
                }
                .padding()
            }
            .presentationDetents([.medium])
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    focusedField = nil
                    onSave()
                }
                .fontWeight(.semibold)
                .foregroundColor(MomentDesign.Colors.accent)
            }
        }
        .onAppear {
            loadTags()
        }
        .sheet(isPresented: $showingTagSheet) {
            TagInputSheet(
                text: .constant(""),
                selectedTags: $tags,
                existingTags: availableTags,
                onAddTag: { name in
                    let newTag = NoteService.shared.createTag(name: name, in: viewContext)
                    tags.insert(newTag)
                    loadTags()
                },
                onToggleTag: { tag in
                    if tags.contains(tag) {
                        tags.remove(tag)
                    } else {
                        tags.insert(tag)
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    private func loadTags() {
        availableTags = NoteService.shared.fetchTags(in: viewContext)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - NoteEditorView for Edit Mode

struct NoteEditorEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var themeManager: ThemeManager

    let noteID: UUID?
    @Binding var title: String
    @Binding var tags: Set<Tag>
    @Binding var content: String
    @Binding var transcript: String
    @Binding var format: NoteFormat
    let date: Date?
    @Binding var images: [Data]
    let audioURL: URL?
    let segments: [TranscriptSegment]
    let onSave: () -> Void
    let onCancel: () -> Void
    let showImagePicker: Bool
    let onSelectLinkedNote: ((Note) -> Void)?
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @Environment(\.colorScheme) var colorScheme
    
    enum Field: Hashable {
        case title, content
    }
    @FocusState private var focusedField: NoteEditorView.Field?
    @State private var editorCommand: EditorCommand? = nil
    @State private var isBulletActive = false
    @State private var isTodoActive = false
    @State private var isTodoChecked = false
    @State private var isH1Active = false
    @State private var isH2Active = false
    @State private var isInitialLoad = true
    @State private var selectedTab: Int = 0
    @State private var hasDeadline = false
    @State private var currentDeadline: Date? = nil
    
    // Deadline State
    @State private var showingDatePicker = false
    @State private var selectedDeadline = Date()
    
    @State private var isGalleryExpanded = false
    @Namespace private var animation
    
    // Tag State
    @State private var showingTagSheet = false
    @State private var availableTags: [Tag] = []
    @State private var followUpNotes: [Note] = []
    @State private var threadNotes: [Note] = []
    @State private var parentNote: Note? = nil
    @State private var currentNoteIsFollowUp = false
    
    // AI Regeneration State
    @StateObject private var aiService = AIService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            MomentDesign.Colors.background
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerView
                        
                        if audioURL != nil {
                            voiceFollowUpSection
                        }
                        
                        if audioURL != nil && !transcript.isEmpty {
                            tabbedContent
                        } else {
                            editorContent
                        }
                    }
                }
                .onTapGesture {
                    focusedField = .content
                }
            }

            // Toolbar Area
            if focusedField != nil {
                NoteToolbar(
                    showImagePicker: showImagePicker,
                    content: $content,
                    selectedItems: $selectedItems,
                    selectedImageCount: images.count,
                    maxImageCount: 9,
                    isBulletActive: isBulletActive,
                    isTodoActive: isTodoActive,
                    isTodoChecked: isTodoChecked,
                    isH1Active: isH1Active,
                    isH2Active: isH2Active,
                    hasDeadline: hasDeadline,
                    onCommand: { command in
                        editorCommand = command
                        HapticHelper.light()
                    },
                    onShowDatePicker: {
                        selectedDeadline = currentDeadline ?? Date()
                        showingDatePicker = true
                        HapticHelper.light()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
            
            // Floating Gallery Overlay
            FloatingGalleryOverlay(
                images: $images,
                isExpanded: $isGalleryExpanded,
                namespace: animation,
                onTapImage: nil,
                onDeleteImage: { index in
                    if index >= 0 && index < images.count {
                        images.remove(at: index)
                    }
                },
                bottomOffset: focusedField != nil ? 60 : 0
            )
            .zIndex(100)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: focusedField)
        .onChange(of: selectedItems) { items in
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let processed = ImageHelper.shared.processImageData(data) {
                        await MainActor.run {
                            if images.count < 9 {
                                images.append(processed)
                            }
                        }
                    }
                }
                await MainActor.run {
                    selectedItems = []
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            VStack {
                DatePicker("Deadline", selection: $selectedDeadline, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                
                HStack {
                    Button("Remove") {
                        editorCommand = .removeDeadline
                        showingDatePicker = false
                        HapticHelper.medium()
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Done") {
                        editorCommand = .setDeadline(selectedDeadline)
                        showingDatePicker = false
                        HapticHelper.success()
                    }
                    .fontWeight(.bold)
                }
                .padding()
            }
            .presentationDetents([.medium])
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !transcript.isEmpty {
                    Button(action: {
                        regenerateContent()
                    }) {
                        if aiService.isSummarizing(noteID: noteID) {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(MomentDesign.Colors.accent)
                        }
                    }
                    .disabled(aiService.isSummarizing(noteID: noteID))
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    focusedField = nil
                    onSave()
                }
                .fontWeight(.semibold)
                .foregroundColor(MomentDesign.Colors.accent)
            }
        }
        .onAppear {
            isInitialLoad = false
            loadTags()
            loadFollowUps()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: viewContext)) { _ in
            loadFollowUps()
        }
        .sheet(isPresented: $showingTagSheet) {
            TagInputSheet(
                text: .constant(""),
                selectedTags: $tags,
                existingTags: availableTags,
                onAddTag: { name in
                    let newTag = NoteService.shared.createTag(name: name, in: viewContext)
                    tags.insert(newTag)
                    loadTags()
                },
                onToggleTag: { tag in
                    if tags.contains(tag) {
                        tags.remove(tag)
                    } else {
                        tags.insert(tag)
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .overlay {
            if aiService.isSummarizing(noteID: noteID) {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        Text("AI is thinking...")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Material.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    )
                }
                .zIndex(100)
            }
        }
    }
    
    private func regenerateContent() {
        guard !aiService.isSummarizing(noteID: noteID) else { return }
        HapticHelper.light()
        
        Task {
            do {
                let result = try await aiService.summarize(text: transcript, format: format, noteID: noteID)
                
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.3)) {
                        content = result.summary
                        if !result.suggestedTitle.isEmpty {
                            title = result.suggestedTitle
                        }
                        selectedTab = 1
                    }
                    HapticHelper.success()
                }
            } catch {
                print("Regeneration failed: \(error)")
                HapticHelper.error()
            }
        }
    }
    
    private var voiceFollowUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if currentNoteIsFollowUp, let parentNote = parentNote {
                linkedNoteButton(parentNote) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(MomentDesign.Colors.accent)
                            .frame(width: 22, height: 22)
                            .background(MomentDesign.Colors.accent.opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Following")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(MomentDesign.Colors.textSecondary)
                            Text(parentNote.displayTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(MomentDesign.Colors.text)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(MomentDesign.Colors.surface.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Follow-ups")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MomentDesign.Colors.text)
                    if currentNoteIsFollowUp {
                        Text(threadNotes.isEmpty ? "This follow-up is not linked into a thread yet." : "\(threadNotes.count) note\(threadNotes.count > 1 ? "s" : "") in this follow-up thread")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    } else {
                        Text(followUpNotes.isEmpty ? "Record a linked follow-up for this note." : "\(followUpNotes.count) linked follow-up note\(followUpNotes.count > 1 ? "s" : "")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Button(action: startFollowUpRecording) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Record")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(MomentDesign.Colors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(MomentDesign.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MomentDesign.Colors.border.opacity(0.35), lineWidth: 1)
            )
            
            if currentNoteIsFollowUp && !threadNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Follow-up Thread")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                        .padding(.leading, 2)
                    
                    ForEach(Array(threadNotes.prefix(6)), id: \.objectID) { threadNote in
                        followUpRow(threadNote, isCurrent: threadNote.id == noteID)
                    }
                }
            } else if !followUpNotes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(followUpNotes.prefix(3)), id: \.objectID) { followUp in
                        followUpRow(followUp, isCurrent: false)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private func followUpRow(_ followUp: Note, isCurrent: Bool) -> some View {
        linkedNoteButton(followUp) {
            HStack(spacing: 10) {
                Image(systemName: isCurrent ? "circle.inset.filled" : "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(MomentDesign.Colors.accent)
                    .frame(width: 22, height: 22)
                    .background(MomentDesign.Colors.accent.opacity(0.12))
                    .clipShape(Circle())
                Text(followUp.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MomentDesign.Colors.text)
                    .lineLimit(1)
                Spacer()
                if isCurrent {
                    Text("CURRENT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(MomentDesign.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(MomentDesign.Colors.accent.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Text(relativeDate(followUp.safeTimestamp))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(MomentDesign.Colors.surface.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrent ? MomentDesign.Colors.accent.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private func linkedNoteButton<Label: View>(_ note: Note, @ViewBuilder label: () -> Label) -> some View {
        if let onSelectLinkedNote {
            Button(action: {
                focusedField = nil
                onSave()
                onSelectLinkedNote(note)
            }) {
                label()
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: note) {
                label()
            }
            .buttonStyle(.plain)
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let date = date {
                HStack {
                    Text(formatDate(date))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                    
                    Spacer()
                    
                    // Format Selector
                    Menu {
                        Picker("Format", selection: $format) {
                            ForEach(NoteFormat.allCases) { f in
                                Label(f.displayName, systemImage: f.icon)
                                    .tag(f)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: format.icon)
                                .font(.system(size: 12))
                            Text(format.displayName)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MomentDesign.Colors.surfaceElevated)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
            }

            TextField("Title", text: $title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(MomentDesign.Colors.text)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .content
                }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }), id: \.id) { tag in
                        TagPill(tag: tag, isSelected: true, isRemovable: true, onSelect: nil) {
                            tags.remove(tag)
                            HapticHelper.light()
                        }
                    }
                    
                    Button(action: {
                        showingTagSheet = true
                        HapticHelper.light()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Tag")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MomentDesign.Colors.surfaceElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(MomentDesign.Colors.border.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
    
    private var tabbedContent: some View {
        VStack(spacing: 0) {
            GeometryReader { tabBarGeo in
                let tabWidth = tabBarGeo.size.width / 2
                let indicatorIndex = CGFloat(selectedTab)
                
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TabButton(title: "Transcript", isSelected: selectedTab == 0) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                selectedTab = 0
                            }
                        }
                        TabButton(title: "Content", isSelected: selectedTab == 1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                selectedTab = 1
                            }
                        }
                    }
                    
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(MomentDesign.Colors.border.opacity(0.35))
                            .frame(height: 1)
                        
                        Rectangle()
                            .fill(MomentDesign.Colors.accent)
                            .frame(width: tabWidth, height: 2)
                            .offset(x: indicatorIndex * tabWidth)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedTab)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .frame(height: 34)
            
            // Tab content — shown conditionally to avoid GeometryReader height collapse inside ScrollView
            ZStack {
                if selectedTab == 0 {
                    TranscriptView(transcript: transcript, audioURL: audioURL, segments: segments)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    editorContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: selectedTab)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        guard value.startLocation.x > 40 else { return }
                        let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.1
                        guard isHorizontal else { return }
                        let threshold: CGFloat = 60
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            if selectedTab == 0 && value.translation.width < -threshold {
                                selectedTab = 1
                            } else if selectedTab == 1 && value.translation.width > threshold {
                                selectedTab = 0
                            }
                        }
                    }
            )
            .clipped()
        }
    }
    
    private var editorContent: some View {
        EditorContentView(
            content: $content,
            command: $editorCommand,
            isBulletActive: $isBulletActive,
            isTodoActive: $isTodoActive,
            isTodoChecked: $isTodoChecked,
            isH1Active: $isH1Active,
            isH2Active: $isH2Active,
            hasDeadline: $hasDeadline,
            currentDeadline: $currentDeadline,
            focusedField: $focusedField,
            images: images,
            onTapImage: nil,
            onDeleteImage: { index in
                if index >= 0 && index < images.count {
                    images.remove(at: index)
                }
            }
        )
    }
    
    private func loadTags() {
        availableTags = NoteService.shared.fetchTags(in: viewContext)
    }
    
    private func loadFollowUps() {
        guard let noteID = noteID else {
            followUpNotes = []
            threadNotes = []
            parentNote = nil
            currentNoteIsFollowUp = false
            return
        }
        
        followUpNotes = NoteService.shared.fetchFollowUpNotes(for: noteID, in: viewContext)
        
        if let currentNote = NoteService.shared.fetchNote(withID: noteID, in: viewContext) {
            if let parentNoteID = currentNote.parentNoteID {
                currentNoteIsFollowUp = true
                parentNote = NoteService.shared.fetchNote(withID: parentNoteID, in: viewContext)
                threadNotes = NoteService.shared.fetchThreadNotes(parentNoteID: parentNoteID, in: viewContext)
            } else {
                currentNoteIsFollowUp = false
                parentNote = nil
                threadNotes = []
            }
        } else {
            currentNoteIsFollowUp = false
            parentNote = nil
            threadNotes = []
        }
    }
    
    private func startFollowUpRecording() {
        guard let noteID = noteID else { return }
        
        focusedField = nil
        onSave()
        
        if GlobalAudioService.shared.isRecording {
            GlobalAudioService.shared.maximize()
            return
        }
        
        HapticHelper.medium()
        Task {
            await GlobalAudioService.shared.startRecording(
                followUpParentNoteID: noteID,
                preferredFormat: format
            )
        }
    }
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Tab Button Component
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? MomentDesign.Colors.accent : MomentDesign.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
        }
    }
}

// MARK: - RichTextEditor (UIViewRepresentable)
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    @Binding var command: EditorCommand?
    @Binding var isBulletActive: Bool
    @Binding var isTodoActive: Bool
    @Binding var isTodoChecked: Bool
    @Binding var isH1Active: Bool
    @Binding var isH2Active: Bool
    @Binding var hasDeadline: Bool
    @Binding var currentDeadline: Date?
    var isFocused: FocusState<NoteEditorView.Field?>.Binding
    var field: NoteEditorView.Field
    
    func makeUIView(context: Context) -> DynamicTextView {
        let textView = DynamicTextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 18)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 24, bottom: 32, right: 24)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textColor = MomentDesign.Colors.textUIColor
        
        // Allow the view to be squeezed horizontally to trigger wrapping
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        textView.onLayout = { [weak textView] in
            guard let textView = textView else { return }
            context.coordinator.recalculateHeight(for: textView)
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: DynamicTextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            // Apply formatting whenever text is externally updated
            context.coordinator.applyFormatting(to: uiView)
            context.coordinator.recalculateHeight(for: uiView)
        }
        
        // Ensure default color is correct (though formatting will override)
        uiView.textColor = MomentDesign.Colors.textUIColor
        
        if let command = command {
            context.coordinator.handle(command, in: uiView)
            DispatchQueue.main.async {
                self.command = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            applyFormatting(to: textView)
            recalculateHeight(for: textView)
            
            DispatchQueue.main.async {
                self.parent.text = textView.text
                self.updateSelectionStates(in: textView)
            }
        }
        
        func recalculateHeight(for textView: UITextView) {
            let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .infinity))
            if size.height != parent.dynamicHeight {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = max(150, size.height)
                }
            }
        }
         
        
        func applyFormatting(to textView: UITextView) {
            let text = textView.text as NSString
            let fullRange = NSRange(location: 0, length: text.length)
            let attributedString = NSMutableAttributedString(string: textView.text)
            
            let bodyFont = UIFont.systemFont(ofSize: 18)
            let bodyColor = MomentDesign.Colors.textUIColor
            attributedString.addAttributes([.font: bodyFont, .foregroundColor: bodyColor], range: fullRange)
            
            let pattern = "^(#+)\\s+(.+)$"
            let deadlinePattern = "@(\\d{4}-\\d{2}-\\d{2})"
            
            // Format Headers
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                regex.enumerateMatches(in: textView.text, options: [], range: fullRange) { match, _, _ in
                    guard let match = match, match.numberOfRanges == 3 else { return }
                    
                    let hashRange = match.range(at: 1)
                    let contentRange = match.range(at: 2)
                    
                    let hashString = text.substring(with: hashRange)
                    
                    if hashString == "#" {
                        if let descriptor = UIFont.systemFont(ofSize: 26, weight: .bold).fontDescriptor.withDesign(.rounded) {
                            let h1Font = UIFont(descriptor: descriptor, size: 26)
                            attributedString.addAttributes([.font: h1Font], range: contentRange)
                        } else {
                             attributedString.addAttributes([.font: UIFont.systemFont(ofSize: 26, weight: .bold)], range: contentRange)
                        }
                    } else if hashString == "##" {
                        if let descriptor = UIFont.systemFont(ofSize: 22, weight: .semibold).fontDescriptor.withDesign(.rounded) {
                            let h2Font = UIFont(descriptor: descriptor, size: 22)
                            attributedString.addAttributes([.font: h2Font], range: contentRange)
                        } else {
                            attributedString.addAttributes([.font: UIFont.systemFont(ofSize: 22, weight: .semibold)], range: contentRange)
                        }
                    }
                    
                    // Hide the Markdown syntax (#, ##) by making it transparent and tiny
                    let hiddenAttributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: UIColor.clear,
                        .font: UIFont.systemFont(ofSize: 1)
                    ]
                    attributedString.addAttributes(hiddenAttributes, range: hashRange)
                }
            }
            
            // Format Deadlines
            if let deadlineRegex = try? NSRegularExpression(pattern: deadlinePattern, options: []) {
                deadlineRegex.enumerateMatches(in: textView.text, options: [], range: fullRange) { match, _, _ in
                    guard let match = match else { return }
                    let range = match.range
                    
                    // Chip Style for Deadline
                    let chipAttributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: UIColor(MomentDesign.Colors.accent),
                        .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                        // Note: UITextView doesn't support rounded background easily without attachments.
                        // We rely on color and font differentiation here.
                        // If we had time, we'd use NSBackgroundColorAttributeName, but it's rectangular.
                        .backgroundColor: UIColor(MomentDesign.Colors.accent).withAlphaComponent(0.1)
                    ]
                    attributedString.addAttributes(chipAttributes, range: range)
                }
            }
            
            let selectedRange = textView.selectedRange
            textView.attributedText = attributedString
            textView.selectedRange = selectedRange
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            updateSelectionStates(in: textView)
        }

        func updateSelectionStates(in textView: UITextView) {
            let range = textView.selectedRange
            let fullText = textView.text as NSString
            
            // Safety check for range
            guard range.location <= fullText.length else { return }
            
            let lineRange = fullText.lineRange(for: range)
            let lineString = fullText.substring(with: lineRange)
            
            // Check for deadline in current line
            let deadlinePattern = "@(\\d{4}-\\d{2}-\\d{2})"
            var deadlineDate: Date? = nil
            
            if let regex = try? NSRegularExpression(pattern: deadlinePattern, options: []) {
                if let match = regex.firstMatch(in: lineString, options: [], range: NSRange(location: 0, length: lineString.utf16.count)) {
                    let dateRange = match.range(at: 1)
                    let dateString = (lineString as NSString).substring(with: dateRange)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    deadlineDate = formatter.date(from: dateString)
                }
            }
            
            DispatchQueue.main.async {
                self.parent.isBulletActive = lineString.hasPrefix("• ")
                self.parent.isTodoActive = lineString.hasPrefix("○ ") || lineString.hasPrefix("● ")
                self.parent.isTodoChecked = lineString.hasPrefix("● ")
                self.parent.isH2Active = lineString.hasPrefix("## ")
                self.parent.isH1Active = lineString.hasPrefix("# ") && !lineString.hasPrefix("## ")
                
                self.parent.hasDeadline = deadlineDate != nil
                self.parent.currentDeadline = deadlineDate
            }
        }
        
        func handle(_ command: EditorCommand, in textView: UITextView) {
            let range = textView.selectedRange
            let fullText = textView.text as NSString
            let lineRange = fullText.lineRange(for: range)
            let lineString = fullText.substring(with: lineRange)
            
            var newLine: String?
            
            switch command {
            case .bullet:
                var cleanedLine = lineString
                if cleanedLine.hasPrefix("○ ") || cleanedLine.hasPrefix("● ") {
                    cleanedLine = String(cleanedLine.dropFirst(2))
                } else if cleanedLine.hasPrefix("## ") {
                    cleanedLine = String(cleanedLine.dropFirst(3))
                } else if cleanedLine.hasPrefix("# ") {
                    cleanedLine = String(cleanedLine.dropFirst(2))
                }
                
                if cleanedLine.hasPrefix("• ") {
                    newLine = String(cleanedLine.dropFirst(2))
                } else {
                    newLine = "• " + cleanedLine
                }
            case .todo:
                var cleanedLine = lineString
                if cleanedLine.hasPrefix("• ") {
                    cleanedLine = String(cleanedLine.dropFirst(2))
                } else if cleanedLine.hasPrefix("## ") {
                    cleanedLine = String(cleanedLine.dropFirst(3))
                } else if cleanedLine.hasPrefix("# ") {
                    cleanedLine = String(cleanedLine.dropFirst(2))
                }
                
                if cleanedLine.hasPrefix("○ ") || cleanedLine.hasPrefix("● ") {
                    newLine = String(cleanedLine.dropFirst(2))
                } else {
                    newLine = "○ " + cleanedLine
                }
            case .h1:
                var cleanedLine = lineString
                if cleanedLine.hasPrefix("• ") {
                    cleanedLine = String(cleanedLine.dropFirst(2))
                } else if cleanedLine.hasPrefix("○ ") || cleanedLine.hasPrefix("● ") {
                    cleanedLine = String(cleanedLine.dropFirst(2))
                } else if cleanedLine.hasPrefix("## ") {
                    cleanedLine = String(cleanedLine.dropFirst(3))
                }
                
                if cleanedLine.hasPrefix("# ") {
                    newLine = String(cleanedLine.dropFirst(2))
                } else {
                    newLine = "# " + cleanedLine
                }
            case .h2:
                var cleanedLine = lineString
                if cleanedLine.hasPrefix("• ") {
                    cleanedLine = String(cleanedLine.dropFirst(2))
                } else if cleanedLine.hasPrefix("○ ") || cleanedLine.hasPrefix("● ") {
                    cleanedLine = String(cleanedLine.dropFirst(2))
                } else if cleanedLine.hasPrefix("# ") {
                    cleanedLine = String(cleanedLine.dropFirst(2))
                }
                
                if cleanedLine.hasPrefix("## ") {
                    newLine = String(cleanedLine.dropFirst(3))
                } else {
                    newLine = "## " + cleanedLine
                }
            case .setDeadline(let date):
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateString = "@" + formatter.string(from: date)
                
                // Remove existing deadline if any
                let deadlinePattern = "\\s*@\\d{4}-\\d{2}-\\d{2}"
                let regex = try? NSRegularExpression(pattern: deadlinePattern, options: [])
                let range = NSRange(location: 0, length: lineString.utf16.count)
                let textWithoutDeadline = regex?.stringByReplacingMatches(in: lineString, options: [], range: range, withTemplate: "") ?? lineString
                
                // Trim trailing whitespace (including newline)
                let trimmedText = textWithoutDeadline.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Append new deadline
                newLine = trimmedText + " " + dateString
                
                // Preserve the newline character if it existed
                if lineString.hasSuffix("\n") {
                    newLine! += "\n"
                }
                
            case .removeDeadline:
                let deadlinePattern = "\\s*@\\d{4}-\\d{2}-\\d{2}"
                let regex = try? NSRegularExpression(pattern: deadlinePattern, options: [])
                let range = NSRange(location: 0, length: lineString.utf16.count)
                let textWithoutDeadline = regex?.stringByReplacingMatches(in: lineString, options: [], range: range, withTemplate: "") ?? lineString
                
                newLine = textWithoutDeadline
            }
            
            if let newLine = newLine {
                let actualOffset = newLine.count - lineString.count
                textView.textStorage.replaceCharacters(in: lineRange, with: newLine)
                
                applyFormatting(to: textView)
                
                DispatchQueue.main.async {
                    self.parent.text = textView.text
                    self.updateSelectionStates(in: textView)
                }
                
                let newLocation = max(0, min(textView.text.count, range.location + actualOffset))
                textView.selectedRange = NSRange(location: newLocation, length: 0)
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                let currentText = textView.text as NSString
                let lineRange = currentText.lineRange(for: NSRange(location: range.location, length: 0))
                let currentLine = currentText.substring(with: lineRange)
                
                if currentLine.prefix(2) == "• " {
                    if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "•" {
                        let newText = currentText.replacingCharacters(in: lineRange, with: "\n")
                        textView.text = newText
                        applyFormatting(to: textView)
                        parent.text = newText
                        updateSelectionStates(in: textView)
                        textView.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
                        return false
                    }
                    textView.insertText("\n• ")
                    return false
                } else if currentLine.prefix(2) == "○ " {
                    if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "○" {
                        let newText = currentText.replacingCharacters(in: lineRange, with: "\n")
                        textView.text = newText
                        applyFormatting(to: textView)
                        parent.text = newText
                        updateSelectionStates(in: textView)
                        textView.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
                        return false
                    }
                    textView.insertText("\n○ ")
                    return false
                } else if currentLine.prefix(2) == "● " {
                    textView.insertText("\n○ ")
                    return false
                } else if currentLine.prefix(3) == "## " {
                    if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "##" {
                        let newText = currentText.replacingCharacters(in: lineRange, with: "\n")
                        textView.text = newText
                        applyFormatting(to: textView)
                        parent.text = newText
                        updateSelectionStates(in: textView)
                        textView.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
                        return false
                    }
                } else if currentLine.prefix(2) == "# " {
                    if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "#" {
                        let newText = currentText.replacingCharacters(in: lineRange, with: "\n")
                        textView.text = newText
                        applyFormatting(to: textView)
                        parent.text = newText
                        updateSelectionStates(in: textView)
                        textView.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
                        return false
                    }
                }
            }
            return true
        }
    }
}

// MARK: - Liquid Glass Helpers (Fallback for older iOS)
struct GlassToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
             content
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
        } else {
            content
                .background(MomentDesign.Colors.surface)
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        }
    }
}

extension View {
    func glassToolbar() -> some View {
        self.modifier(GlassToolbarModifier())
    }
}
