//
//  RootTabView.swift
//  ContraLLM
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }

            VoiceRecordingsView()
                .tabItem { Label("Voice", systemImage: "mic.circle") }

            CanvaView()
                .tabItem { Label("Canva", systemImage: "paintpalette") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(ContraTheme.accent)
    }
}

#Preview {
    RootTabView()
}
