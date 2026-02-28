//
//  ImageCardThumbnails.swift
//  moment
//
//  Compact image thumbnails row for note cards (max 3 visible)
//

import SwiftUI

struct ImageCardThumbnails: View {
    let images: [Data]
    
    private let thumbnailHeight: CGFloat = 80
    private let cornerRadius: CGFloat = 12
    private let spacing: CGFloat = 4
    
    private var displayImages: [Data] {
        Array(images.prefix(3))
    }
    
    private var extraCount: Int {
        max(0, images.count - 3)
    }
    
    var body: some View {
        let count = displayImages.count
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: max(1, count))
        
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(displayImages.enumerated()), id: \.offset) { index, data in
                ZStack {
                    if let image = ImageHelper.shared.image(from: data) {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .frame(height: thumbnailHeight)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                    
                    if index == 2 && extraCount > 0 {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.black.opacity(0.5))
                        
                        Text("+\(extraCount)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .frame(height: thumbnailHeight)
    }
}
