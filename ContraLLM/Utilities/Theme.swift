//
//  Theme.swift
//  ContraLLM
//
//  Central design tokens for the Minimal / Premium / White aesthetic.
//

import SwiftUI
import UIKit

enum ContraTheme {
    // Backgrounds
    static let background = Color(light: 0xFFFFFF, dark: 0x0B0B0C)
    static let surface = Color(light: 0xFAFAFA, dark: 0x141416)
    static let surfaceElevated = Color(light: 0xFFFFFF, dark: 0x1C1C1F)

    // Text
    static let textPrimary = Color(light: 0x111111, dark: 0xF5F5F5)
    static let textSecondary = Color(light: 0x6B6B6F, dark: 0x9B9BA1)
    static let textTertiary = Color(light: 0xA3A3A8, dark: 0x6E6E73)

    // Accent — used sparingly: active/AI state, highlights, progress.
    static let accent = Color(light: 0x3B5BFD, dark: 0x6C87FF)
    static let accentSoft = Color(light: 0xEDF0FF, dark: 0x1B2140)

    // Structure
    static let border = Color(light: 0xE7E7EA, dark: 0x2A2A2E)
    static let shadow = Color.black.opacity(0.06)

    // Radii
    static let cardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 16
    static let chipRadius: CGFloat = 12
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(hex: hex)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ContraTheme.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: ContraTheme.cardRadius, style: .continuous)
                    .stroke(ContraTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: ContraTheme.cardRadius, style: .continuous))
            .shadow(color: ContraTheme.shadow, radius: 12, x: 0, y: 4)
    }
}

extension View {
    func contraCard(padding: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding))
    }
}
