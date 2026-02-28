//  NoteTypeSelectionView.swift
//  moment
//
//  Created by wen li on 2026/1/8.
//

import SwiftUI

struct NoteTypeSelectionView: View {
    let onSelectText: () -> Void
    let onSelectAudio: () -> Void
    let onSelectImage: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("创建新笔记")
                .font(.title2.bold())
                .padding(.top, 8)

            HStack(spacing: 12) {
                // 文本笔记按钮
                Button(action: {
                    onSelectText()
                    dismiss()
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 30))
                        Text("文本笔记")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)

                // 录音笔记按钮
                Button(action: {
                    onSelectAudio()
                    dismiss()
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 30))
                        Text("录音笔记")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                
                // 图片笔记按钮
                Button(action: {
                    onSelectImage()
                    dismiss()
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 30))
                        Text("图片笔记")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }


        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MomentDesign.Colors.surface)
        .presentationDetents([.height(280)])
    }
}
