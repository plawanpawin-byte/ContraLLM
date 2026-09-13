//
//  SettingsView.swift
//  ContraLLM
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var configStore = APIConfigurationStore.shared
    @State private var showDeveloperMode = false
    @State private var customEndpoint = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Label("iOS 17+", systemImage: "iphone")
                    Label("Contra LLM v1.0", systemImage: "info.circle")
                }

                Section("AI") {
                    Toggle("Use demo AI provider", isOn: $configStore.configuration.useMockProviders)
                    Text("Contra never stores AI provider keys on this device. Requests are routed through the Contra backend, which connects to your configured AI provider.")
                        .font(.system(size: 12))
                        .foregroundStyle(ContraTheme.textSecondary)

                    Toggle("Developer Mode", isOn: $showDeveloperMode)
                    if showDeveloperMode {
                        TextField("Custom backend URL", text: $customEndpoint)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                if let url = URL(string: customEndpoint) {
                                    configStore.configuration.baseURL = url
                                }
                            }
                        Text("Current: \(configStore.configuration.baseURL.absoluteString)")
                            .font(.system(size: 12))
                            .foregroundStyle(ContraTheme.textTertiary)
                    }
                }

                Section("Voice") {
                    Label("Voice: Contra (default)", systemImage: "waveform")
                    Text("Speech-to-text and text-to-speech run through the same provider abstraction, so a production voice provider can be swapped in without UI changes.")
                        .font(.system(size: 12))
                        .foregroundStyle(ContraTheme.textSecondary)
                }

                Section("About") {
                    Label("Contra LLM", systemImage: "sparkles")
                    Text("Contra turns what you want to understand — a PDF, a link, a video, an audio file — into something you can read, listen to, and explore.")
                        .font(.system(size: 12))
                        .foregroundStyle(ContraTheme.textSecondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
