import Cocoa
import CoreImage

enum ImageProcessor {
    static func process(_ data: Data, settings: SettingsStore) -> Data {
        guard let source = CIImage(data: data) else { return data }
        var image = source

        if settings.imageAutoRotate {
            image = image.oriented(forExifOrientation: Int32(image.properties[kCGImagePropertyOrientation as String] as? Int ?? 1))
        }

        if settings.imageTrimWhitespace {
            image = trimWhitespace(image)
        }

        if settings.imageAutoEnhance {
            let filters = image.autoAdjustmentFilters()
            for filter in filters {
                filter.setValue(image, forKey: kCIInputImageKey)
                if let output = filter.outputImage {
                    image = output
                }
            }
        }

        if settings.imageSharpen {
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(image, forKey: kCIInputImageKey)
                filter.setValue(0.8, forKey: kCIInputSharpnessKey)
                if let output = filter.outputImage {
                    image = output
                }
            }
        }

        if settings.imageReduceNoise {
            if let filter = CIFilter(name: "CINoiseReduction") {
                filter.setValue(image, forKey: kCIInputImageKey)
                filter.setValue(0.05, forKey: "inputNoiseLevel")
                filter.setValue(0.5, forKey: kCIInputSharpnessKey)
                if let output = filter.outputImage {
                    image = output
                }
            }
        }

        if settings.imageGrayscale {
            if let filter = CIFilter(name: "CIPhotoEffectMono") {
                filter.setValue(image, forKey: kCIInputImageKey)
                if let output = filter.outputImage {
                    image = output
                }
            }
        }

        return renderToData(image, settings: settings, stripMetadata: settings.imageStripMetadata)
    }

    private static func renderToData(_ image: CIImage, settings: SettingsStore, stripMetadata: Bool) -> Data {
        let context = CIContext()
        let extent = image.extent

        guard let cgImage = context.createCGImage(image, from: extent) else {
            return NSBitmapImageRep(ciImage: image).representation(using: .png, properties: [:]) ?? Data()
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)

        if stripMetadata {
            rep.setProperty(.exifData, withValue: [:] as [String: Any])
        }

        if settings.imageConvertToPNG {
            return rep.representation(using: .png, properties: [:]) ?? Data()
        }

        if settings.imageConvertToJPEG {
            let quality = CGFloat(settings.imageQuality) / 100.0
            return rep.representation(using: .jpeg, properties: [.compressionFactor: quality]) ?? Data()
        }

        return rep.representation(using: .png, properties: [:]) ?? Data()
    }

    private static func trimWhitespace(_ image: CIImage) -> CIImage {
        let context = CIContext()
        let extent = image.extent
        guard let cgImage = context.createCGImage(image, from: extent) else { return image }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        let width = rep.pixelsWide
        let height = rep.pixelsHigh

        var minX = width, minY = height, maxX = 0, maxY = 0
        let threshold: CGFloat = 0.95

        for y in 0 ..< height {
            for x in 0 ..< width {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                let r = color.redComponent
                let g = color.greenComponent
                let b = color.blueComponent
                if r < threshold || g < threshold || b < threshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX > minX, maxY > minY else { return image }

        let padding = 2
        let cropX = max(0, minX - padding)
        let cropY = max(0, minY - padding)
        let cropW = min(width - cropX, maxX - minX + 1 + padding * 2)
        let cropH = min(height - cropY, maxY - minY + 1 + padding * 2)

        let flippedY = CGFloat(height - cropY - cropH)
        let cropRect = CGRect(x: CGFloat(cropX), y: flippedY, width: CGFloat(cropW), height: CGFloat(cropH))

        return image.cropped(to: cropRect)
    }
}
