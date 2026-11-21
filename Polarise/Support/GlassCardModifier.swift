//
//  GlassCardModifier.swift
//  Polarise
//
//  Created by Nikunj Mathur on 17/11/26.
//

import Foundation
import SwiftUI

enum GlassShapeStyle {
    case card(cornerRadius: CGFloat = 28)
    case capsule
    case circle
}

struct GlassCardModifier: ViewModifier {
    let style: GlassShapeStyle
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            switch style {
            case .card(let radius):
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: radius))
            case .capsule:
                content
                    .glassEffect(.regular, in: .capsule)
            case .circle:
                content
                    .glassEffect(.regular, in: .circle)
            }
        } else {
            switch style {
            case .card(let radius):
                content
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 0.75)
                    )
            case .capsule:
                content
                    .background(.regularMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.22), lineWidth: 0.75)
                    )
            case .circle:
                content
                    .background(.regularMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.22), lineWidth: 0.75)
                    )
            }
        }
    }
}

extension View {
    func polariseGlass(_ style: GlassShapeStyle = .card()) -> some View {
        modifier(GlassCardModifier(style: style))
    }
}
