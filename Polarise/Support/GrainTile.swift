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
        let scale      = Int(NSScreen.main?.backingScaleFactor ?? 2)
        let logicalSize  = 512
        let physicalSize = logicalSize * scale
        let image = makeNoiseTile(physicalSize: physicalSize, logicalSize: logicalSize)
        return NSColor(patternImage: image)
    }()

    private static func makeNoiseTile(physicalSize: Int, logicalSize: Int) -> NSImage {
        let pixelCount = physicalSize * physicalSize

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
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            return NSImage(size: NSSize(width: logicalSize, height: logicalSize))
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: logicalSize, height: logicalSize))
    }
}
