//
//  QRCodeGenerator.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

protocol QRCodeGenerating {
    func image(for value: String) -> NSImage?
}

struct QRCodeGenerator: QRCodeGenerating {
    private let context = CIContext()

    func image(for value: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage?.transformed(by: .init(scaleX: 10, y: 10)),
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: 280, height: 280))
    }
}
