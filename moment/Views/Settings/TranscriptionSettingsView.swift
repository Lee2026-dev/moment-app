
import SwiftUI

struct TranscriptionSettingsView: View {
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage: String = "zh"
    
    var body: some View {
        ZStack {
            MomentDesign.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Transcription")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 18))
                                    .foregroundColor(MomentDesign.Colors.accent)
                                    .frame(width: 28)
                                
                                Text("Language")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(MomentDesign.Colors.text)
                                
                                Spacer()
                                
                                Picker("", selection: $transcriptionLanguage) {
                                    Text("中文").tag("zh")
                                    Text("English").tag("en")
                                }
                                .pickerStyle(.menu)
                                .tint(MomentDesign.Colors.accent)
                                .onChange(of: transcriptionLanguage) { _ in
                                    HapticHelper.light()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .background(MomentDesign.Colors.surface)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(MomentDesign.Colors.border.opacity(0.5), lineWidth: 0.5)
                        )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Transcription")
    }
}
