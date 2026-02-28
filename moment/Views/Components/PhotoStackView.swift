//
//  PhotoStackView.swift
//  moment
//
//  Created by Antigravity on 2026/01/26.
//

import SwiftUI

struct PhotoStackView: View {
    let images: [Data]
    var namespace: Namespace.ID
    var onTap: (() -> Void)? = nil
    
    // We only show top 3 images in the stack for performance and aesthetics
    private var displayImages: [Data] {
        Array(images.prefix(3).reversed()) // Reverse so first image is on top (z-index)
    }
    
    var body: some View {
        ZStack {
            if images.isEmpty {
                EmptyView()
            } else {
                ForEach(Array(displayImages.enumerated()), id: \.offset) { index, data in
                    // Real index relative to original reversed array
                    // if count is 3: index 0 is (original 2), index 1 is (original 1), index 2 is (original 0 - top)
                    
                    // We want consistent rotation for same image position
                    // Top image (last in loop) should be index 0 equivalent for math
                    let stackPos = displayImages.count - 1 - index
                    let realIndex = (displayImages.count - 1) - index
                    
                    StackPhotoCard(data: data)
                        .matchedGeometryEffect(id: "image-\(realIndex)", in: namespace)
                        .rotationEffect(.degrees(rotation(for: stackPos)))
                        .offset(x: offset(for: stackPos).width, y: offset(for: stackPos).height)
                        .scaleEffect(scale(for: stackPos))
                        .zIndex(Double(index))
                }
            }
        }
        .frame(height: 220) // Fixed height for the stack container
        .frame(maxWidth: .infinity)
        .onTapGesture {
            HapticHelper.light()
            onTap?()
        }
    }
    
    // Pseudo-random but deterministic values based on index
    private func rotation(for index: Int) -> Double {
        let rotations = [-6.0, 4.0, -2.0]
        if index < rotations.count { return rotations[index] }
        return 0
    }
    
    private func offset(for index: Int) -> CGSize {
        let offsets = [
            CGSize(width: -4, height: 4),
            CGSize(width: 6, height: -2),
            CGSize(width: 0, height: 0)
        ]
        if index < offsets.count { return offsets[index] }
        return .zero
    }
    
    private func scale(for index: Int) -> CGFloat {
        // Items further back are slightly smaller
        return 1.0 - (CGFloat(index) * 0.05)
    }
}

private struct StackPhotoCard: View {
    let data: Data
    
    var body: some View {
        Group {
            if let image = ImageHelper.shared.image(from: data) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipped()
            } else {
                Rectangle().fill(Color.gray.opacity(0.3))
                    .frame(width: 160, height: 160)
            }
        } // Square polaroid aspect
        .overlay(
            // Polaroid-style white border
            Rectangle()
                .stroke(Color.white, lineWidth: 8)
        )
        // Container shape including border background
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}
