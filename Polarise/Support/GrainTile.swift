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
        // Render at screen backing scale so each noise pixel is exactly
        // one physical pixel on Retina — sharp, film-grain-like particles.
        let scale      = Int(NSScreen.main?.backingScaleFactor ?? 2)
        let logicalSize  = 512
        let physicalSize = logicalSize * scale
        let image = makeNoiseTile(physicalSize: physicalSize, logicalSize: logicalSize)
        return NSColor(patternImage: image)
    }()

    private static func makeNoiseTile(physicalSize: Int, logicalSize: Int) -> NSImage {
        let pixelCount = physicalSize * physicalSize

        // Full 0–255 luminance range: gives visible dark → bright grain variance.
        // The layer's opacity (grainOpacity setting) controls overall intensity.
        // Using the full range lets individual grain particles be truly distinct,
        // matching the analog film-grain look (high contrast between neighbours).
        var pixels = [UInt8](repeating: 0, count: pixelCount)
        var seed: UInt64 = 0x9E3779B97F4A7C15
        for i in 0..<pixelCount {
            seed ^= seed >> 12
            seed ^= seed << 25
            seed ^= seed >> 27
            pixels[i] = UInt8((seed &* 0x2545F4914F6CDD1D) >> 56)
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let data = Data(pixels)

        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width:  physicalSize,
                height: physicalSize,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: physicalSize,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,   // keep each grain pixel sharp, no anti-aliasing
                intent: .defaultIntent
              )
        else {
            return NSImage(size: NSSize(width: logicalSize, height: logicalSize))
        }

        // Logical size tells AppKit how to tile at the correct screen density
        return NSImage(cgImage: cgImage, size: NSSize(width: logicalSize, height: logicalSize))
    }
}
