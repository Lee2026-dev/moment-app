
import SwiftUI

struct AboutView: View {
    var body: some View {
        ZStack {
            MomentDesign.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image("AppIcon") // Assuming AppIcon exists, or use a system placeholder
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(20)
                            .padding(.top, 40)
                        
                        Text("Moment")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(MomentDesign.Colors.text)
                        
                        Text("Version 1.0.0 (Pro-Max)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text("Developer")
                                Spacer()
                                Text("Wen Li")
                                    .foregroundColor(MomentDesign.Colors.textSecondary)
                            }
                            .padding()
                        }
                        .background(MomentDesign.Colors.surface)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle("About")
    }
}
