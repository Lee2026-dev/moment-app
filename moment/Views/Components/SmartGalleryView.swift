//
//  SmartGalleryView.swift
//  moment
//
//  Created by Antigravity on 2026/01/26.
//

import SwiftUI

struct SmartGalleryView: View {
    let images: [Data]
    var onTap: ((Int) -> Void)? = nil
    var onDelete: ((Int) -> Void)? = nil
    var namespace: Namespace.ID
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left Column (Even indices)
            LazyVStack(spacing: 12) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                    if index % 2 == 0 {
                        SmartImageCell(data: data, index: index, namespace: namespace, onTap: onTap, onDelete: onDelete)
                    }
                }
            }
            
            // Right Column (Odd indices)
            LazyVStack(spacing: 12) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                    if index % 2 != 0 {
                        SmartImageCell(data: data, index: index, namespace: namespace, onTap: onTap, onDelete: onDelete)
                    }
                }
            }
        }
        .padding(.horizontal, 2) // Minor padding to avoid clipping shadows slightly
    }
}

private struct SmartImageCell: View {
    let data: Data
    let index: Int
    var namespace: Namespace.ID
    var onTap: ((Int) -> Void)?
    var onDelete: ((Int) -> Void)?
    
    @State private var aspectRatio: CGFloat = 1.0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: {
                onTap?(index)
            }) {
                if let image = ImageHelper.shared.image(from: data) {
                    image
                        .resizable()
                        .scaledToFit() // Maintain aspect ratio naturally
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(MomentDesign.Colors.border.opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: MomentDesign.Colors.shadow.opacity(0.08), radius: 8, x: 0, y: 4)
                        .matchedGeometryEffect(id: "image-\(index)", in: namespace)
                } else {
                    Rectangle()
                        .fill(MomentDesign.Colors.surfaceElevated)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .matchedGeometryEffect(id: "image-\(index)", in: namespace)
                }
            }
            .buttonStyle(PlainButtonStyle()) // No flash on tap
            
            if let onDelete = onDelete {
                Button(action: {
                    HapticHelper.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onDelete(index)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(.ultraThinMaterial) // Apple style glass effect
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .padding(8)
            }
        }
    }
}
