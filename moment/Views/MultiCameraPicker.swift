//
//  MultiCameraPicker.swift
//  moment
//
//  Camera picker with multi-capture support
//

import SwiftUI
import UIKit

struct MultiCameraPicker: UIViewControllerRepresentable {
    @Binding var capturedImages: [Data]
    let maxCount: Int
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MultiCameraPicker
        
        init(_ parent: MultiCameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                if let data = uiImage.jpegData(compressionQuality: 0.8),
                   let processed = ImageHelper.shared.processImageData(data) {
                    DispatchQueue.main.async {
                        self.parent.capturedImages.append(processed)
                        HapticHelper.light()
                        
                        if self.parent.capturedImages.count < self.parent.maxCount {
                            self.showContinueAlert(picker: picker)
                        } else {
                            self.parent.dismiss()
                        }
                    }
                }
            }
        }
        
        private func showContinueAlert(picker: UIImagePickerController) {
            let remaining = parent.maxCount - parent.capturedImages.count
            
            let alert = UIAlertController(
                title: "Photo Captured",
                message: "You can add \(remaining) more photos",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Continue (\(parent.capturedImages.count)/\(parent.maxCount))", style: .default) { _ in
                picker.dismiss(animated: false) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            let newPicker = UIImagePickerController()
                            newPicker.sourceType = .camera
                            newPicker.delegate = self
                            rootVC.present(newPicker, animated: true)
                        }
                    }
                }
            })
            
            alert.addAction(UIAlertAction(title: "Done", style: .cancel) { _ in
                HapticHelper.success()
                self.parent.dismiss()
            })
            
            picker.present(alert, animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
