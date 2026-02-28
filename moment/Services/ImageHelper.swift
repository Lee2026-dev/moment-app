//
//  ImageHelper.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import Foundation
import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Utility class for image processing operations using CoreGraphics and ImageIO to avoid UIKit dependency
class ImageHelper {
    static let shared = ImageHelper()
    
    private init() {}
    
    /// Maximum dimensions for images (maintains aspect ratio)
    static let maxImageDimension: CGFloat = 1024
    
    /// Compresses and resizes an image from Data
    /// - Parameters:
    ///   - data: Original image data
    ///   - maxDimension: Maximum width or height
    ///   - compressionQuality: JPEG compression quality 0.0-1.0 (default: 0.7)
    /// - Returns: Compressed image data, or nil
    func processImageData(_ data: Data, maxDimension: CGFloat = maxImageDimension, compressionQuality: CGFloat = 0.7) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        
        // Resize if needed
        let resizedImage = resizeCGImage(cgImage, maxDimension: maxDimension)
        
        // Compress to JPEG
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        
        CGImageDestinationAddImage(destination, resizedImage, options as CFDictionary)
        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        }
        
        return nil
    }
    
    /// Resizes a CGImage while maintaining aspect ratio
    private func resizeCGImage(_ image: CGImage, maxDimension: CGFloat) -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        
        if width <= maxDimension && height <= maxDimension {
            return image
        }
        
        let aspectRatio = width / height
        var newSize: CGSize
        
        if width > height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        let context = CGContext(data: nil,
                                width: Int(newSize.width),
                                height: Int(newSize.height),
                                bitsPerComponent: image.bitsPerComponent,
                                bytesPerRow: 0,
                                space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: image.bitmapInfo.rawValue)
        
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: newSize))
        
        return context?.makeImage() ?? image
    }
    
    /// Creates a SwiftUI Image from Data
    /// - Parameter data: The image data
    /// - Returns: SwiftUI Image, or nil if conversion fails
    func image(from data: Data) -> Image? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        // Note: We use cgImage:orientation: but orientation is tricky without UIKit/UIImage.
        // For a simple case, we assume up. Real production code might need to extract metadata.
        return Image(cgImage, scale: 1.0, label: Text("Note Image"))
    }
    
    /// Gets the file size of image data in KB
    /// - Parameter data: The image data
    /// - Returns: File size in kilobytes
    func getImageSizeInKB(_ data: Data) -> Double {
        return Double(data.count) / 1024.0
    }
    
    func processImages(_ dataArray: [Data], maxDimension: CGFloat = maxImageDimension, compressionQuality: CGFloat = 0.7) -> [Data] {
        return dataArray.compactMap { processImageData($0, maxDimension: maxDimension, compressionQuality: compressionQuality) }
    }
    
    /// Gets image dimensions from Data without fully decoding if possible
    func getImageDimensions(_ data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let propertiesOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, propertiesOptions) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}
