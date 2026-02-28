//
//  EditProfileView.swift
//  moment
//
//  Created by Moment AI on 2026/01/25.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var name: String
    @State private var selectedImageData: Data?
    @State private var showActionSheet = false
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var showCartoonDesigner = false
    @State private var removeExistingAvatar = false
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(currentName: String) {
        _name = State(initialValue: currentName)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                MomentDesign.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Edit Profile")
                            .font(MomentDesign.Typography.Fonts.title)
                            .foregroundColor(MomentDesign.Colors.text)
                        
                        Text("Update your personal details below.")
                            .font(MomentDesign.Typography.Fonts.body)
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Avatar Section
                    VStack(spacing: 8) {
                        ZStack {
                            if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                // 1. Newly selected / just-captured image
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if !removeExistingAvatar, let data = authService.cachedAvatarData, let uiImage = UIImage(data: data) {
                                // 2. Local cache (instant, no network)
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                // 3. No avatar at all
                                ZStack {
                                    Circle().fill(MomentDesign.Colors.surface)
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(MomentDesign.Colors.textSecondary)
                                        .padding(16)
                                }
                                .frame(width: 100, height: 100)
                            }
                            
                            // Pencil edit button — positioned in bottom-right corner
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button(action: { showActionSheet = true }) {
                                        ZStack {
                                            Circle().fill(MomentDesign.Colors.accent)
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "pencil")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .offset(x: -4, y: -4)
                                }
                            }
                        }
                        .frame(width: 110, height: 110)
                        .shadow(color: MomentDesign.Colors.accent.opacity(0.25), radius: 10, x: 0, y: 5)
                    }
                    
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name")
                                .font(MomentDesign.Typography.Fonts.caption)
                                .foregroundColor(MomentDesign.Colors.textSecondary)
                                .padding(.leading, 4)
                            
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(MomentDesign.Colors.accent)
                                
                                TextField("Your Name", text: $name)
                                    .font(MomentDesign.Typography.Fonts.body)
                                    .foregroundColor(MomentDesign.Colors.text)
                                    .autocapitalization(.words)
                                    .disableAutocorrection(true)
                                
                                if !name.isEmpty {
                                    Button(action: { name = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(MomentDesign.Colors.textSecondary)
                                    }
                                }
                            }
                            .padding()
                            .background(MomentDesign.Colors.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(MomentDesign.Colors.border, lineWidth: 1)
                            )
                        }
                        
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(MomentDesign.Typography.Fonts.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        Button(action: saveProfile) {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Save Changes")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(name.isEmpty ? Color.gray : MomentDesign.Colors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: MomentDesign.Colors.accent.opacity(name.isEmpty ? 0 : 0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(name.isEmpty || isLoading)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(MomentDesign.Colors.textSecondary)
                }
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(title: Text("Update Portrait"), buttons: [
                .default(Text("Choose from Library")) {
                    showImagePicker = true
                },
                .default(Text("Take Photo")) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCameraPicker = true
                    }
                },
                .default(Text("Design Avatar")) {
                    showCartoonDesigner = true
                },
                .destructive(Text("Remove Portrait")) {
                    selectedImageData = nil
                    removeExistingAvatar = true
                },
                .cancel()
            ])
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedData: $selectedImageData)
        }
        .sheet(isPresented: $showCameraPicker) {
            CameraPicker(selectedData: $selectedImageData)
        }
        .fullScreenCover(isPresented: $showCartoonDesigner) {
            CartoonPortraitDesignerView(selectedImageData: $selectedImageData)
        }
    }
    
    private func saveProfile() {
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else { return }
        
        HapticHelper.light() // Instant feedback
        
        // 1. Optimistic UI Updates - instantly patch the data state
        if let current = authService.currentUser {
            authService.currentUser = UserProfile(
                id: current.id,
                email: current.email,
                created_at: current.created_at,
                loadedName: finalName,
                avatarUrl: current.avatarUrl
            )
        }
        
        if removeExistingAvatar {
            authService.cachedAvatarData = nil
        } else if let newData = selectedImageData {
            authService.cachedAvatarData = newData
        }
        
        // 2. Capture immutable state for the detached async block
        let capturedRemoveAvatar = removeExistingAvatar
        let capturedImageData = selectedImageData
        let capturedAuthService = authService
        let capturedName = finalName
        
        // 3. Fire-and-forget networking task
        Task {
            do {
                var uploadAvatarUrl = capturedAuthService.currentUser?.avatarUrl
                
                if capturedRemoveAvatar {
                    uploadAvatarUrl = nil
                } else if let newData = capturedImageData {
                    uploadAvatarUrl = try await capturedAuthService.uploadProfileImage(data: newData)
                }
            
                try await capturedAuthService.updateUserProfile(name: capturedName, avatarUrl: uploadAvatarUrl)
                HapticHelper.success() // Vibrate when the background sync actually clears
            } catch {
                print("Failed background profile update: \(error)")
                HapticHelper.medium()
            }
        }
        
        // 4. Instant visual dismissal
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    EditProfileView(currentName: "Sisyphus")
}
