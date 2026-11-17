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
        let image = makeNoiseTile(size: 256)
        return NSColor(patternImage: image)
    }()
    
    private static func makeNoiseTile(size: Int) -> NSImage {
        let pixelCount = size * size
        var pixels = [UInt8](repeating: 0, count: pixelCount)
        
        var seed: UInt64 = 0x9E3779B97F4A7C15
        for i in 0..<pixelCount {
            seed ^= seed >> 12
            seed ^= seed << 25
            seed ^= seed >> 27
            let val = UInt8((seed &* 0x2545F4914F6CDD1D) >> 56)
            pixels[i] = val
        }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let data = Data(pixels)
        
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(width: size,
                                    height: size,
                                    bitsPerComponent: 8,
                                    bitsPerPixel: 8,
                                    bytesPerRow: size,
                                    space: colorSpace,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                    provider: provider,
                                    decode: nil,
                                    shouldInterpolate: false,
                                    intent: .defaultIntent
              ) else {
            return NSImage(size: NSSize(width: size, height: size))
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
