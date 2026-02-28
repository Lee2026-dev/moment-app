//
//  ImagePreviewGridView.swift
//  moment
//
//  Editable image grid with delete and add more functionality
//

import SwiftUI
import PhotosUI

struct ImagePreviewGridView: View {
    @Binding var images: [Data]
    let maxCount: Int
    var onAddMore: (() -> Void)?
    var onTapImage: ((Int) -> Void)?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let cellHeight: CGFloat = 100
    private let cornerRadius: CGFloat = 16
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                ImageThumbnailCell(
                    imageData: data,
                    cornerRadius: cornerRadius,
                    height: cellHeight,
                    onTap: { onTapImage?(index) },
                    onDelete: { deleteImage(at: index) }
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            if images.count < maxCount {
                AddMoreButton(
                    remaining: maxCount - images.count,
                    cornerRadius: cornerRadius,
                    height: cellHeight,
                    action: { onAddMore?() }
                )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: images.count)
    }
    
    private func deleteImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        HapticHelper.light()
        images.remove(at: index)
    }
}

struct ImageThumbnailCell: View {
    let imageData: Data
    let cornerRadius: CGFloat
    let height: CGFloat
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ImageHelper.shared.image(from: imageData)?
                .resizable()
                .scaledToFill()
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(MomentDesign.Colors.border.opacity(0.3), lineWidth: 0.5)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .onTapGesture {
                    onTap?()
                }
                .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isPressed = pressing
                    }
                    if pressing {
                        HapticHelper.medium()
                    }
                }, perform: {})
            
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }
                .padding(6)
            }
        }
    }
}

struct AddMoreButton: View {
    let remaining: Int
    let cornerRadius: CGFloat
    let height: CGFloat
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticHelper.light()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                Text("Add (\(remaining))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundColor(MomentDesign.Colors.textSecondary)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(MomentDesign.Colors.border)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
    }
}
