//
//  CartoonPortraitDesignerView.swift
//  moment
//
//  Created by Moment AI on 2026/02/23.
//

import SwiftUI

// MARK: - Color Palette Presets

struct AvatarPalette: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let colors: [Color]
    
    static func == (lhs: AvatarPalette, rhs: AvatarPalette) -> Bool {
        lhs.id == rhs.id
    }
    
    static let presets: [AvatarPalette] = [
        AvatarPalette(id: "sunset", name: "Sunset", icon: "sun.horizon.fill", colors: [
            Color(red: 1.0, green: 0.42, blue: 0.42),   // Coral
            Color(red: 1.0, green: 0.60, blue: 0.35),   // Tangerine
            Color(red: 1.0, green: 0.82, blue: 0.44),   // Amber
            Color(red: 0.95, green: 0.35, blue: 0.55),   // Rose
            Color(red: 0.98, green: 0.72, blue: 0.60),   // Peach
        ]),
        AvatarPalette(id: "ocean", name: "Ocean", icon: "water.waves", colors: [
            Color(red: 0.05, green: 0.45, blue: 0.85),   // Cobalt
            Color(red: 0.10, green: 0.65, blue: 0.88),   // Cerulean
            Color(red: 0.30, green: 0.82, blue: 0.88),   // Aqua
            Color(red: 0.55, green: 0.90, blue: 0.92),   // Ice
            Color(red: 0.15, green: 0.35, blue: 0.70),   // Deep Sea
        ]),
        AvatarPalette(id: "aurora", name: "Aurora", icon: "sparkles", colors: [
            Color(red: 0.55, green: 0.27, blue: 0.88),   // Violet
            Color(red: 0.80, green: 0.35, blue: 0.75),   // Orchid
            Color(red: 0.30, green: 0.75, blue: 0.85),   // Cyan
            Color(red: 0.45, green: 0.90, blue: 0.70),   // Mint
            Color(red: 0.70, green: 0.40, blue: 0.95),   // Lavender
        ]),
        AvatarPalette(id: "forest", name: "Forest", icon: "leaf.fill", colors: [
            Color(red: 0.10, green: 0.58, blue: 0.42),   // Emerald
            Color(red: 0.25, green: 0.72, blue: 0.45),   // Jade
            Color(red: 0.55, green: 0.82, blue: 0.35),   // Lime
            Color(red: 0.18, green: 0.48, blue: 0.30),   // Pine
            Color(red: 0.65, green: 0.85, blue: 0.55),   // Fern
        ]),
        AvatarPalette(id: "earth", name: "Earth", icon: "mountain.2.fill", colors: [
            Color(red: 0.72, green: 0.48, blue: 0.32),   // Terracotta
            Color(red: 0.88, green: 0.72, blue: 0.55),   // Sand
            Color(red: 0.55, green: 0.38, blue: 0.28),   // Umber
            Color(red: 0.78, green: 0.62, blue: 0.45),   // Camel
            Color(red: 0.92, green: 0.82, blue: 0.68),   // Cream
        ]),
        AvatarPalette(id: "neon", name: "Neon", icon: "bolt.fill", colors: [
            Color(red: 1.0, green: 0.15, blue: 0.55),    // Hot Pink
            Color(red: 0.10, green: 1.0, blue: 0.80),    // Electric Teal
            Color(red: 0.85, green: 1.0, blue: 0.15),    // Acid Yellow
            Color(red: 0.45, green: 0.20, blue: 1.0),    // Electric Purple
            Color(red: 1.0, green: 0.55, blue: 0.10),    // Electric Orange
        ]),
        AvatarPalette(id: "pastel", name: "Pastel", icon: "cloud.fill", colors: [
            Color(red: 1.0, green: 0.82, blue: 0.86),    // Blush
            Color(red: 0.78, green: 0.85, blue: 1.0),    // Periwinkle
            Color(red: 0.82, green: 0.95, blue: 0.85),   // Mint Cream
            Color(red: 1.0, green: 0.92, blue: 0.80),    // Butter
            Color(red: 0.90, green: 0.82, blue: 0.98),   // Lilac
        ]),
        AvatarPalette(id: "mono", name: "Mono", icon: "circle.lefthalf.filled", colors: [
            Color(red: 0.15, green: 0.15, blue: 0.18),   // Charcoal
            Color(red: 0.35, green: 0.35, blue: 0.40),   // Slate
            Color(red: 0.60, green: 0.60, blue: 0.65),   // Silver
            Color(red: 0.82, green: 0.82, blue: 0.85),   // Ash
            Color(red: 0.95, green: 0.95, blue: 0.96),   // Ghost
        ]),
    ]
}

// MARK: - Geometric Shape Types

enum GeoShape: String, CaseIterable, Identifiable {
    case circle, halfCircle, triangle, square, diamond, hexagon
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .circle: return "circle.fill"
        case .halfCircle: return "circle.lefthalf.filled"
        case .triangle: return "triangle.fill"
        case .square: return "square.fill"
        case .diamond: return "diamond.fill"
        case .hexagon: return "hexagon.fill"
        }
    }
}

// MARK: - Shape Layer Model

struct ShapeLayer: Identifiable {
    let id = UUID()
    var shape: GeoShape
    var colorIndex: Int       // index into palette
    var x: CGFloat            // 0...1 normalized position
    var y: CGFloat
    var size: CGFloat         // 0.2...0.8 relative
    var rotation: Double      // degrees
    var opacity: Double       // 0.3...1.0
}

// MARK: - Deterministic Random Generator

struct SeededRandom {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(abs(seed)) &+ 1
    }
    
    mutating func next() -> Double {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 10000) / 10000.0
    }
    
    mutating func nextInRange(_ min: Double, _ max: Double) -> Double {
        return min + next() * (max - min)
    }
    
    mutating func nextInt(_ max: Int) -> Int {
        return Int(next() * Double(max)) % max
    }
}

// MARK: - Main View

struct CartoonPortraitDesignerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedImageData: Data?
    
    @State private var selectedPalette: AvatarPalette = AvatarPalette.presets[0]
    @State private var layers: [ShapeLayer] = []
    @State private var seed: Int = Int.random(in: 1...99999)
    @State private var complexity: Int = 5  // number of shapes: 3-7
    @State private var isSymmetric: Bool = true
    @State private var animatePreview: Bool = false
    @State private var previewRotation: Double = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview
                previewSection
                
                // Controls
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        paletteSelector
                        complexitySlider
                        symmetryToggle
                        randomizeButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                applyButton
            }
            .background(MomentDesign.Colors.background.ignoresSafeArea())
            .navigationTitle("Design Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(MomentDesign.Colors.textSecondary))
            .onAppear {
                generateLayers()
                withAnimation(.easeInOut(duration: 0.8)) {
                    animatePreview = true
                }
            }
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        ZStack {
            // Ambient glow behind avatar
            Circle()
                .fill(
                    RadialGradient(
                        colors: [selectedPalette.colors.first?.opacity(0.3) ?? .clear, .clear],
                        center: .center,
                        startRadius: 60,
                        endRadius: 160
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 20)
            
            // The actual avatar
            avatarView
                .frame(width: 220, height: 220)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
                .scaleEffect(animatePreview ? 1.0 : 0.8)
                .opacity(animatePreview ? 1.0 : 0.0)
        }
        .frame(height: 280)
        .padding(.top, 8)
    }
    
    // MARK: - Palette Selector
    
    private var paletteSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Color Palette")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AvatarPalette.presets) { palette in
                        paletteChip(palette)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
    }
    
    private func paletteChip(_ palette: AvatarPalette) -> some View {
        let isSelected = selectedPalette == palette
        
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedPalette = palette
                generateLayers()
            }
            HapticHelper.light()
        }) {
            VStack(spacing: 6) {
                // Color preview: stacked circles
                ZStack {
                    ForEach(0..<min(palette.colors.count, 4), id: \.self) { i in
                        Circle()
                            .fill(palette.colors[i])
                            .frame(width: 28, height: 28)
                            .offset(
                                x: CGFloat(i - 1) * 6,
                                y: CGFloat(i % 2 == 0 ? -3 : 3)
                            )
                    }
                }
                .frame(width: 50, height: 40)
                
                Text(palette.name)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? MomentDesign.Colors.accent : MomentDesign.Colors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? MomentDesign.Colors.accent.opacity(0.12) : MomentDesign.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? MomentDesign.Colors.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Complexity Slider
    
    private var complexitySlider: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Complexity")
                Spacer()
                Text("\(complexity) shapes")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(MomentDesign.Colors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(MomentDesign.Colors.accent.opacity(0.1))
                    .cornerRadius(8)
            }
            
            HStack(spacing: 16) {
                Image(systemName: "square.fill")
                    .font(.system(size: 12))
                    .foregroundColor(MomentDesign.Colors.textSecondary)
                
                Slider(
                    value: Binding(
                        get: { Double(complexity) },
                        set: { newVal in
                            let newComplexity = Int(newVal)
                            if newComplexity != complexity {
                                complexity = newComplexity
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    generateLayers()
                                }
                                HapticHelper.light()
                            }
                        }
                    ),
                    in: 3...8,
                    step: 1
                )
                .tint(MomentDesign.Colors.accent)
                
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 14))
                    .foregroundColor(MomentDesign.Colors.textSecondary)
            }
            .padding()
            .background(MomentDesign.Colors.surface)
            .cornerRadius(14)
        }
    }
    
    // MARK: - Symmetry Toggle
    
    private var symmetryToggle: some View {
        HStack {
            Image(systemName: isSymmetric ? "arrow.left.and.right.righttriangle.left.righttriangle.right.fill" : "scribble.variable")
                .font(.system(size: 16))
                .foregroundColor(MomentDesign.Colors.accent)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isSymmetric ? "Symmetric" : "Freeform")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(MomentDesign.Colors.text)
                Text(isSymmetric ? "Balanced, harmonious layout" : "Organic, free-flowing composition")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(MomentDesign.Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isSymmetric },
                set: { newVal in
                    isSymmetric = newVal
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        generateLayers()
                    }
                    HapticHelper.light()
                }
            ))
            .tint(MomentDesign.Colors.accent)
        }
        .padding()
        .background(MomentDesign.Colors.surface)
        .cornerRadius(14)
    }
    
    // MARK: - Randomize Button
    
    private var randomizeButton: some View {
        Button(action: {
            seed = Int.random(in: 1...99999)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                generateLayers()
            }
            HapticHelper.light()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.bounce, value: seed)
                Text("Randomize")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(MomentDesign.Colors.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(MomentDesign.Colors.surface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(MomentDesign.Colors.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Apply Button
    
    private var applyButton: some View {
        Button(action: applyDesign) {
            Text("Apply Portrait")
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(MomentDesign.Colors.accent)
                .foregroundColor(.white)
                .cornerRadius(16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .padding(.top, 8)
    }
    
    // MARK: - Section Label
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(MomentDesign.Colors.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
    
    // MARK: - Avatar Rendering View
    
    var avatarView: some View {
        GeometryReader { geo in
            ZStack {
                // Background: subtle gradient from the palette
                LinearGradient(
                    colors: [
                        selectedPalette.colors.last?.opacity(0.25) ?? Color.gray.opacity(0.1),
                        selectedPalette.colors.first?.opacity(0.15) ?? Color.gray.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle noise texture effect via concentric faint circles
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(Color.white.opacity(0.03), lineWidth: 1)
                        .frame(
                            width: geo.size.width * CGFloat(0.4 + Double(ring) * 0.25),
                            height: geo.size.width * CGFloat(0.4 + Double(ring) * 0.25)
                        )
                }
                
                // Shape layers
                ForEach(layers) { layer in
                    shapeView(for: layer, in: geo.size)
                }
                
                // Premium overlay: subtle vignette
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.08)],
                    center: .center,
                    startRadius: geo.size.width * 0.3,
                    endRadius: geo.size.width * 0.55
                )
                
                // Glass-like inner highlight
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.5)
                    .offset(y: -geo.size.height * 0.15)
                    .blendMode(.overlay)
            }
            .clipShape(Circle())
        }
    }
    
    // MARK: - Individual Shape Rendering
    
    @ViewBuilder
    private func shapeView(for layer: ShapeLayer, in size: CGSize) -> some View {
        let color = selectedPalette.colors[layer.colorIndex % selectedPalette.colors.count]
        let shapeSize = size.width * layer.size
        let posX = (layer.x - 0.5) * size.width
        let posY = (layer.y - 0.5) * size.height
        
        Group {
            switch layer.shape {
            case .circle:
                Circle()
                    .fill(color.opacity(layer.opacity))
                    
            case .halfCircle:
                HalfCircleShape()
                    .fill(color.opacity(layer.opacity))
                    
            case .triangle:
                TriangleShape()
                    .fill(color.opacity(layer.opacity))
                    
            case .square:
                RoundedRectangle(cornerRadius: shapeSize * 0.1)
                    .fill(color.opacity(layer.opacity))
                    
            case .diamond:
                RoundedRectangle(cornerRadius: shapeSize * 0.08)
                    .fill(color.opacity(layer.opacity))
                    .rotationEffect(.degrees(45))
                    
            case .hexagon:
                HexagonShape()
                    .fill(color.opacity(layer.opacity))
            }
        }
        .frame(width: shapeSize, height: shapeSize)
        .rotationEffect(.degrees(layer.rotation))
        .offset(x: posX, y: posY)
    }
    
    // MARK: - Layer Generation
    
    private func generateLayers() {
        var rng = SeededRandom(seed: seed)
        var newLayers: [ShapeLayer] = []
        let allShapes = GeoShape.allCases
        
        for i in 0..<complexity {
            let shapeIndex = rng.nextInt(allShapes.count)
            let colorIdx = rng.nextInt(selectedPalette.colors.count)
            
            var x: CGFloat
            var y: CGFloat
            
            if isSymmetric {
                // For symmetric: place shapes around center with mirroring consideration
                let angle = (Double(i) / Double(complexity)) * .pi * 2.0 + rng.nextInRange(-0.3, 0.3)
                let radius = rng.nextInRange(0.05, 0.28)
                x = 0.5 + CGFloat(cos(angle) * radius)
                y = 0.5 + CGFloat(sin(angle) * radius)
            } else {
                x = CGFloat(rng.nextInRange(0.15, 0.85))
                y = CGFloat(rng.nextInRange(0.15, 0.85))
            }
            
            let size = CGFloat(rng.nextInRange(0.2, 0.55))
            let rotation = isSymmetric
                ? rng.nextInRange(-30, 30)
                : rng.nextInRange(0, 360)
            let opacity = rng.nextInRange(0.4, 0.95)
            
            newLayers.append(ShapeLayer(
                shape: allShapes[shapeIndex],
                colorIndex: colorIdx,
                x: x,
                y: y,
                size: size,
                rotation: rotation,
                opacity: opacity
            ))
        }
        
        layers = newLayers
    }
    
    // MARK: - Apply / Export
    
    private func applyDesign() {
        let renderSize: CGFloat = 400
        let content = avatarView
            .frame(width: renderSize, height: renderSize)
            .clipShape(Circle())
        
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            selectedImageData = uiImage.pngData()
            HapticHelper.success()
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Custom Shapes

struct HalfCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3.0 - .pi / 6.0
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
