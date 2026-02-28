//
//  MultiImagePicker.swift
//  moment
//
//  Multi-image picker using PhotosPicker (iOS 16+)
//

import SwiftUI
import PhotosUI

struct MultiImagePicker: View {
    @Binding var selectedImages: [Data]
    let maxCount: Int
    var onDismiss: (() -> Void)?
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var remainingSlots: Int {
        max(0, maxCount - selectedImages.count)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading images...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            if selectedImages.isEmpty {
                                PhotosPicker(
                                    selection: $selectedItems,
                                    maxSelectionCount: remainingSlots,
                                    matching: .images,
                                    preferredItemEncoding: .automatic
                                ) {
                                    VStack(spacing: 16) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 60))
                                            .foregroundColor(MomentDesign.Colors.accent)
                                        
                                        Text("Select up to \(remainingSlots) images")
                                            .font(.system(size: 17, weight: .medium, design: .rounded))
                                            .foregroundColor(MomentDesign.Colors.text)
                                        
                                        Text("\(selectedImages.count)/\(maxCount) selected")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(MomentDesign.Colors.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 100)
                                }
                            } else {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(selectedImages.count)/\(maxCount) Selected")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(MomentDesign.Colors.text)
                                        Text("Select up to \(maxCount) images total")
                                            .font(.system(size: 13))
                                            .foregroundColor(MomentDesign.Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if remainingSlots > 0 {
                                        PhotosPicker(
                                            selection: $selectedItems,
                                            maxSelectionCount: remainingSlots,
                                            matching: .images,
                                            preferredItemEncoding: .automatic
                                        ) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "plus")
                                                Text("Add More")
                                            }
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(MomentDesign.Colors.accent)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.top, 20)
                                
                                let columns = [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ]
                                
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, data in
                                        ZStack(alignment: .topTrailing) {
                                            if let image = ImageHelper.shared.image(from: data) {
                                                Rectangle()
                                                    .fill(Color.clear)
                                                    .aspectRatio(1, contentMode: .fit)
                                                    .overlay(
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                    )
                                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                                                    .clipped()
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 15)
                                                            .stroke(MomentDesign.Colors.border.opacity(0.3), lineWidth: 0.5)
                                                    )
                                            }
                                            
                                            Button(action: {
                                                _ = withAnimation {
                                                    selectedImages.remove(at: index)
                                                }
                                                HapticHelper.light()
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.4)))
                                                    .shadow(radius: 2)
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(MomentDesign.Colors.background)
            .navigationTitle("Select Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss?()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedImages.isEmpty {
                        Button("Done") {
                            dismiss()
                            onDismiss?()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .onChange(of: selectedItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await loadImages(from: items)
            }
        }
    }
    
    @MainActor
    private func loadImages(from items: [PhotosPickerItem]) async {
        isLoading = true
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                if let processed = ImageHelper.shared.processImageData(data) {
                    selectedImages.append(processed)
                }
            }
        }
        
        selectedItems = []
        isLoading = false
        HapticHelper.success()
    }
}

struct MultiImagePickerSheet: View {
    @Binding var selectedImages: [Data]
    let maxCount: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        MultiImagePicker(
            selectedImages: $selectedImages,
            maxCount: maxCount,
            onDismiss: { isPresented = false }
        )
    }
}
