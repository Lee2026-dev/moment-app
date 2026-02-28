//
//  UserView.swift
//  moment
//

import SwiftUI
import CoreData

struct UserView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "audioURL == nil OR audioURL == ''")
    ) private var textNotes: FetchedResults<Note>
    
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "audioURL != nil AND audioURL != ''")
    ) private var voiceNotes: FetchedResults<Note>
    
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isFavorite == YES")
    ) private var favoriteNotes: FetchedResults<Note>

    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isSignUpMode = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isShowingEditProfile = false
    
    var body: some View {
        NavigationView {
            ZStack {
                MomentDesign.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        if authService.isLoggedIn {
                            profileHeader
                            statsView
                            actionsSection
                        } else {
                            authForm
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                
                if isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle(authService.isLoggedIn ? "Profile" : (isSignUpMode ? "Create Account" : "Welcome Back"))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: authService.isLoggedIn) { newValue in
                if newValue {
                    withAnimation {
                        isLoading = false
                    }
                }
            }
            .onChange(of: authService.authError) { newValue in
                if newValue != nil {
                    withAnimation {
                        isLoading = false
                    }
                }
            }
            .onChange(of: isSignUpMode) { _ in
                authService.authError = nil
            }
            .task(id: authService.isLoggedIn) {
                guard authService.isLoggedIn else { return }
                await authService.fetchUserStats()
            }
            .sheet(isPresented: $isShowingEditProfile) {
                if let currentName = authService.currentUser?.name {
                    EditProfileView(currentName: currentName)
                }
            }
        }
    }
    
    // MARK: - Logged In View
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                if let data = authService.cachedAvatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [MomentDesign.Colors.accent, MomentDesign.Colors.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Text(authService.currentUser?.name.prefix(1) ?? "U")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Pencil edit button — positioned in bottom-right corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isShowingEditProfile = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(MomentDesign.Colors.surface)
                                    .frame(width: 32, height: 32)
                                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                                
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(MomentDesign.Colors.accent)
                            }
                        }
                    }
                }
            }
            .frame(width: 110, height: 110)
            .shadow(color: MomentDesign.Colors.accent.opacity(0.25), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 4) {
                Text(authService.currentUser?.name ?? "User")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(MomentDesign.Colors.text)
                
                Text(authService.currentUser?.email ?? "")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(MomentDesign.Colors.textSecondary)
            }
        }
    }
    
    private var statsView: some View {
        HStack(spacing: 12) {
            statItem(label: "Notes", value: "\(textNotes.count + voiceNotes.count)", icon: "note.text")
            statItem(label: "Recordings", value: "\(voiceNotes.count)", icon: "waveform")
            statItem(label: "AI Summaries", value: "\(authService.aiSummarizeCount)", icon: "sparkles")
        }
        .padding(.horizontal)
    }
    
    private func statItem(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(MomentDesign.Colors.accent)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(MomentDesign.Colors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(MomentDesign.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(MomentDesign.Colors.surface)
        .cornerRadius(16)
        .shadow(color: MomentDesign.Colors.shadow, radius: 5, x: 0, y: 2)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 1) {
            actionRow(icon: "paintpalette.fill", title: "Appearance", color: .purple, destination: AnyView(ThemeSettingsView()))
            actionRow(icon: "waveform.circle.fill", title: "Transcription", color: .blue, destination: AnyView(TranscriptionSettingsView()))
            actionRow(icon: "calendar.badge.clock", title: "Calendar & Reminders", color: .green, destination: AnyView(CalendarSettingsView()))
            actionRow(icon: "info.circle.fill", title: "About", color: .gray, destination: AnyView(AboutView()))
            
            Button(action: {
                authService.signOut()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    Text("Sign Out")
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding()
                .background(MomentDesign.Colors.surface)
            }
        }
        .cornerRadius(16)
        .padding(.horizontal)
    }



    private func themeCircle(option: ThemeOption) -> some View {
        let isSelected = themeManager.selectedTheme == option
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                themeManager.selectedTheme = option
                HapticHelper.medium()
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themePreviewColor(for: option))
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(
                    Circle()
                        .stroke(MomentDesign.Colors.accent, lineWidth: isSelected ? 3 : 0)
                        .padding(-4)
                )
                
                Text(option.displayName)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? MomentDesign.Colors.accent : MomentDesign.Colors.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func themePreviewColor(for option: ThemeOption) -> Color {
        switch option {
        case .system: return Color.gray
        case .classic: return Color(hex: "6366F1")
        case .midnightGold: return Color(hex: "F7E7CE")
        case .deepOcean: return Color(hex: "0EA5E9")
        case .emeraldForest: return Color(hex: "10B981")
        case .royalPurple: return Color(hex: "8B5CF6")
        }
    }
    
    private func actionRow(icon: String, title: String, color: Color, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(MomentDesign.Colors.text)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MomentDesign.Colors.textSecondary.opacity(0.5))
            }
            .padding()
            .background(MomentDesign.Colors.surface)
        }
    }
    
    // MARK: - Auth Form View
    
    private var authForm: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(isSignUpMode ? "Create Account" : "Simplify Your Life")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(MomentDesign.Colors.text)
                
                Text(isSignUpMode ? "Join us to start capturing your moments." : "Sign in to sync your notes across devices.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(MomentDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 40)
            
            VStack(spacing: 16) {
                if isSignUpMode {
                    customTextField(placeholder: "Full Name", text: $name, icon: "person")
                }
                
                customTextField(placeholder: "Email Address", text: $email, icon: "envelope", keyboardType: .emailAddress)
                
                customSecureField(placeholder: "Password", text: $password, icon: "lock")
            }
            .padding(.horizontal, 24)
            
            if let error = authService.authError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                handleAuth()
            }) {
                Text(isSignUpMode ? "Register" : "Sign In")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(MomentDesign.Colors.accent)
                    .cornerRadius(14)
                    .shadow(color: MomentDesign.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            Button(action: {
                withAnimation {
                    isSignUpMode.toggle()
                    authService.authError = nil
                }
            }) {
                HStack(spacing: 4) {
                    Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                    Text(isSignUpMode ? "Sign In" : "Sign Up")
                        .foregroundColor(MomentDesign.Colors.accent)
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
            }
            
            if !isSignUpMode {
                Button(action: {}) {
                    Text("Forgot Password?")
                        .font(.system(size: 14))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                }
            }
        }
    }
    
    private func customTextField(placeholder: String, text: Binding<String>, icon: String, keyboardType: UIKeyboardType = .default) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(MomentDesign.Colors.accent)
                .frame(width: 20)
            
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
        }
        .padding()
        .background(MomentDesign.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MomentDesign.Colors.border, lineWidth: 1)
        )
    }
    
    private func customSecureField(placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(MomentDesign.Colors.accent)
                .frame(width: 20)
            
            SecureField(placeholder, text: text)
        }
        .padding()
        .background(MomentDesign.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MomentDesign.Colors.border, lineWidth: 1)
        )
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .transition(.opacity)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(MomentDesign.Colors.accent)
                
                Text(isSignUpMode ? "Creating Account..." : "Signing In...")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(MomentDesign.Colors.text)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            )
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
        .zIndex(100)
    }
    
    private func handleAuth() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validations
        if trimmedEmail.isEmpty || trimmedPassword.isEmpty || (isSignUpMode && trimmedName.isEmpty) {
            authService.authError = "Please fill in all fields."
            return
        }

        if !isValidEmail(trimmedEmail) {
            authService.authError = "Please enter a valid email address."
            return
        }
        
        withAnimation {
            isLoading = true
        }
        if isSignUpMode {
            authService.signUp(name: trimmedName, email: trimmedEmail, password: trimmedPassword)
        } else {
            authService.signIn(email: trimmedEmail, password: trimmedPassword)
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

#Preview {
    UserView()
}
