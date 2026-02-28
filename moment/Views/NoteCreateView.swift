//
//  NoteCreateView.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import SwiftUI
import CoreData

struct NoteCreateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var controller: NoteCreateController

    init(initialImages: [Data] = [], onNoteCreated: (() -> Void)? = nil) {
        _controller = StateObject(wrappedValue: NoteCreateController(
            viewContext: PersistenceController.shared.container.viewContext,
            initialImages: initialImages,
            onNoteCreated: onNoteCreated
        ))
    }
    
    init(initialImage: Data?, onNoteCreated: (() -> Void)? = nil) {
        let images: [Data] = initialImage.map { [$0] } ?? []
        _controller = StateObject(wrappedValue: NoteCreateController(
            viewContext: PersistenceController.shared.container.viewContext,
            initialImages: images,
            onNoteCreated: onNoteCreated
        ))
    }

    var body: some View {
        NavigationView {
            NoteEditorView(
                title: $controller.title,
                tags: $controller.tags,
                content: $controller.content,
                format: $controller.format,
                date: nil,
                images: $controller.selectedImages,
                onSave: { controller.saveNote(dismiss: dismiss) },
                onCancel: { },
                showImagePicker: true
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
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
            .alert("Error", isPresented: $controller.showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(controller.errorMessage)
            }
        }
    }
}

#Preview {
    NoteCreateView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
