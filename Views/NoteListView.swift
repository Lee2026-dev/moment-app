struct NoteDetailView: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var editedContent: String = ""

    var body: some View {
        ScrollView {
            if isEditing {
                // Editing mode - true edge-to-edge
                VStack(alignment: .leading, spacing: 20) {
                    // Title field - true iPhone Notes style, NO padding
                    TextField("Title", text: $editedTitle)
                        .font(.system(size: 24, weight: .bold))
                        .textFieldStyle(.plain)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity)

                    Divider()

                    // Content field - true edge-to-edge, NO padding
                    TextEditor(text: $editedContent)
                        .font(.system(size: 17))
                        .frame(minHeight: 300)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)

                    // Image (read-only in edit mode) - true edge-to-edge, NO padding
                    if let imageData = note.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 20)
            } else {
                // Reading mode - true edge-to-edge, no side padding
                VStack(alignment: .leading, spacing: 20) {
                    // Title - true iPhone Notes style, NO horizontal padding
                    Text(note.displayTitle)
                        .font(.system(size: 24, weight: .bold))
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // Content - true edge-to-edge, NO horizontal padding
                    Group {
                        if let content = note.content, !content.isEmpty {
                            Text(content)
                                .font(.system(size: 17))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("No content")
                                .font(.system(size: 17))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Image - true edge-to-edge, NO horizontal padding
                    if let imageData = note.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
        }
        .onAppear {
            // Initialize editing state
            editedTitle = note.title ?? ""
            editedContent = note.content ?? ""
        }
    }

    private func startEditing() {
        editedTitle = note.title ?? ""
        editedContent = note.content ?? ""
        isEditing = true
    }

    private func saveChanges() {
        note.title = editedTitle.isEmpty ? nil : editedTitle
        note.content = editedContent.isEmpty ? nil : editedContent
        
        do {
            try viewContext.save()
            isEditing = false
        } catch {
            print("Failed to save note: \(error.localizedDescription)")
        }
    }

    private func cancelEditing() {
        editedTitle = note.title ?? ""
        editedContent = note.content ?? ""
        isEditing = false
    }
}
