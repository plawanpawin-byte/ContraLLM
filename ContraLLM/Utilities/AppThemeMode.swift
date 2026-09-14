//
//  AppThemeMode.swift
//  ContraLLM
//
//  User-selectable appearance mode (Settings -> Appearance), independent of
//  the light/dark color tokens in Theme.swift which already adapt to
//  whichever scheme ends up active.
//

import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// nil lets SwiftUI follow the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppStorageKey {
    static let themeMode = "com.contra.llm.themeMode"
    static let displayName = "com.contra.llm.displayName"
}
