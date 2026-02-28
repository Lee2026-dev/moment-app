//
//  ImageGridView.swift
//  moment
//
//  Multi-image grid display component with adaptive layouts
//

import SwiftUI

enum ImageGridMode {
    case card
    case editor
    case preview
    case fullscreen
}

struct ImageGridView: View {
    let images: [Data]
    let mode: ImageGridMode
    var onTap: ((Int) -> Void)?
    var onDelete: ((Int) -> Void)?
    
    private var spacing: CGFloat {
        switch mode {
        case .card: return 4
        case .editor, .preview: return 6
        case .fullscreen: return 2
        }
    }
    
    private var cornerRadius: CGFloat {
        switch mode {
        case .card: return 12
        case .editor: return 20
        case .preview: return 16
        case .fullscreen: return 8
        }
    }
    
    private var maxHeight: CGFloat {
        switch mode {
        case .card: return 120
        case .editor: return 400
        case .preview: return 300
        case .fullscreen: return .infinity
        }
    }
    
    var body: some View {
        Group {
            switch images.count {
            case 0:
                EmptyView()
            case 1:
                singleImageView
            case 2:
                twoImagesView
            case 3:
                threeImagesView
            case 4:
                fourImagesView
            default:
                multiImagesView
            }
        }
    }
    
    private var singleImageView: some View {
        imageCell(at: 0)
            .aspectRatio(4/3, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: mode == .card ? 120 : 300)
    }
    
    private var twoImagesView: some View {
        HStack(spacing: spacing) {
            imageCell(at: 0)
                .aspectRatio(1, contentMode: .fill)
            imageCell(at: 1)
                .aspectRatio(1, contentMode: .fill)
        }
        .frame(height: mode == .card ? 100 : 180)
    }
    
    private var threeImagesView: some View {
        HStack(spacing: spacing) {
            imageCell(at: 0)
                .aspectRatio(2/3, contentMode: .fill)
            
            VStack(spacing: spacing) {
                imageCell(at: 1)
                    .aspectRatio(1, contentMode: .fill)
                imageCell(at: 2)
                    .aspectRatio(1, contentMode: .fill)
            }
        }
        .frame(height: mode == .card ? 120 : 200)
    }
    
    private var fourImagesView: some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                imageCell(at: 0)
                    .aspectRatio(1, contentMode: .fill)
                imageCell(at: 1)
                    .aspectRatio(1, contentMode: .fill)
            }
            HStack(spacing: spacing) {
                imageCell(at: 2)
                    .aspectRatio(1, contentMode: .fill)
                imageCell(at: 3)
                    .aspectRatio(1, contentMode: .fill)
            }
        }
        .frame(height: mode == .card ? 120 : 240)
    }
    
    private var multiImagesView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
        
        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(images.prefix(9).enumerated()), id: \.offset) { index, _ in
                imageCell(at: index)
                    .aspectRatio(1, contentMode: .fill)
            }
        }
        .frame(maxHeight: maxHeight)
    }
    
    @ViewBuilder
    private func imageCell(at index: Int) -> some View {
        if index < images.count {
            ZStack(alignment: .topTrailing) {
                ImageHelper.shared.image(from: images[index])?
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap?(index)
                    }
                
                if let onDelete = onDelete, mode == .preview {
                    Button(action: {
                        HapticHelper.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onDelete(index)
                        }
                    }) {
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
}
