//
//  GrainTile.swift
//  Polarise
//
//  Created by Nikunj Mathur on 17/11/26.
//

import Foundation
import AppKit

enum GrainTile {
    static let patternColor: NSColor = {
        // Render at 2× so each noise pixel maps to one physical pixel on Retina.
        let scale = Int(NSScreen.main?.backingScaleFactor ?? 2)
        let logicalSize = 512
        let physicalSize = logicalSize * scale
        let image = makeNoiseTile(physicalSize: physicalSize, logicalSize: logicalSize)
        return NSColor(patternImage: image)
    }()

    private static func makeNoiseTile(physicalSize: Int, logicalSize: Int) -> NSImage {
        let pixelCount = physicalSize * physicalSize

        // Noise is centred on mid-grey (128) with a tight ±20 spread.
        // This gives fine, almost-invisible grain instead of harsh black/white speckles.
        let centre: Int = 128
        let spread: Int = 20

        var pixels = [UInt8](repeating: 0, count: pixelCount)
        var seed: UInt64 = 0x9E3779B97F4A7C15
        for i in 0..<pixelCount {
            seed ^= seed >> 12
            seed ^= seed << 25
            seed ^= seed >> 27
            // Map the full 0–255 raw value into [centre-spread … centre+spread]
            let raw = Int((seed &* 0x2545F4914F6CDD1D) >> 56)   // 0–255
            let mapped = centre - spread + (raw * (spread * 2)) / 255
            pixels[i] = UInt8(clamping: mapped)
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let data = Data(pixels)

        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: physicalSize,
                height: physicalSize,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: physicalSize,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,   // soft edges between noise pixels
                intent: .defaultIntent
              )
        else {
            return NSImage(size: NSSize(width: logicalSize, height: logicalSize))
        }

        // Set logical size so AppKit tiles at the correct density
        return NSImage(cgImage: cgImage, size: NSSize(width: logicalSize, height: logicalSize))
    }
}
