//
//  TagComponents.swift
//  moment
//
//  Created by wen li on 2026/1/25.
//

import SwiftUI
import CoreData

// MARK: - Tag Pill Component
struct TagPill: View {
    let tag: Tag
    let isSelected: Bool
    let isRemovable: Bool
    let onSelect: (() -> Void)?
    let onRemove: (() -> Void)?
    
    var body: some View {
        Button(action: { onSelect?() }) {
            HStack(spacing: 4) {
                Text("#" + (tag.name ?? ""))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                
                if isRemovable {
                    Button(action: { onRemove?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : MomentDesign.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? MomentDesign.Colors.accent : MomentDesign.Colors.surfaceElevated)
            )
            .overlay(
                Capsule()
                    .stroke(MomentDesign.Colors.accent.opacity(isSelected ? 0 : 0.1), lineWidth: 1)
            )
            .foregroundColor(isSelected ? .white : MomentDesign.Colors.text)
            .shadow(color: isSelected ? MomentDesign.Colors.accent.opacity(0.3) : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Tag Input Sheet
struct TagInputSheet: View {
    @Binding var text: String
    @Binding var selectedTags: Set<Tag>
    let existingTags: [Tag]
    let onAddTag: (String) -> Void
    let onToggleTag: (Tag) -> Void
    
    @State private var inputTag: String = ""
    @FocusState private var isFocused: Bool
    
    var filteredTags: [Tag] {
        if inputTag.isEmpty {
            return existingTags
        } else {
            return existingTags.filter { ($0.name ?? "").localizedCaseInsensitiveContains(inputTag) }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Manage Tags")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal)
            
            // Input Field
            HStack {
                Image(systemName: "number")
                    .foregroundColor(MomentDesign.Colors.textSecondary)
                TextField("Add new tag...", text: $inputTag)
                    .font(.system(size: 16))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if !inputTag.isEmpty {
                            onAddTag(inputTag)
                            inputTag = ""
                        }
                    }
                
                if !inputTag.isEmpty {
                    Button("Add") {
                        onAddTag(inputTag)
                        inputTag = ""
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MomentDesign.Colors.accent)
                }
            }
            .padding(12)
            .background(MomentDesign.Colors.surface)
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Tag Cloud
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SUGGESTED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(filteredTags, id: \.id) { tag in
                            TagPill(
                                tag: tag,
                                isSelected: selectedTags.contains(tag),
                                isRemovable: false,
                                onSelect: {
                                    onToggleTag(tag)
                                    HapticHelper.light()
                                },
                                onRemove: nil
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
        }
        .background(MomentDesign.Colors.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            isFocused = true
        }
    }
}
