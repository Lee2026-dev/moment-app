//
//  ImageGalleryView.swift
//  moment
//
//  Full-screen image gallery with swipe navigation and zoom
//

import SwiftUI

struct ImageGalleryView: View {
    let images: [Data]
    @Binding var isPresented: Bool
    @State private var currentIndex: Int
    @GestureState private var dragOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = 1.0
    
    init(images: [Data], isPresented: Binding<Bool>, startIndex: Int = 0) {
        self.images = images
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: startIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                    ZoomableImageView(imageData: data)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragOffset.height)
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        HapticHelper.light()
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                if images.count > 1 {
                    PageIndicator(count: images.count, current: currentIndex)
                        .padding(.bottom, 50)
                }
            }
        }
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    if value.translation.height > 0 {
                        state = value.translation
                        let progress = min(value.translation.height / 300, 1.0)
                        DispatchQueue.main.async {
                            backgroundOpacity = 1.0 - (progress * 0.5)
                        }
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        isPresented = false
                    } else {
                        withAnimation(.spring()) {
                            backgroundOpacity = 1.0
                        }
                    }
                }
        )
        .statusBarHidden()
    }
}

struct ZoomableImageView: View {
    let imageData: Data
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ImageHelper.shared.image(from: imageData)?
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = min(max(newScale, 1.0), 4.0)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale <= 1.0 {
                                withAnimation(.spring()) {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct PageIndicator: View {
    let count: Int
    let current: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.white : Color.white.opacity(0.4))
                    .frame(width: index == current ? 8 : 6, height: index == current ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
