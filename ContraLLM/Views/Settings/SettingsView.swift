//
//  SettingsView.swift
//  ContraLLM
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var configStore = APIConfigurationStore.shared
    @State private var showDeveloperMode = false
    @State private var customEndpoint = ""
    @State private var sharedSecret = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Label("iOS 17+", systemImage: "iphone")
                    Label("Contra LLM v1.0", systemImage: "info.circle")
                }

                Section("AI") {
                    Toggle("Use demo AI provider", isOn: $configStore.configuration.useMockProviders)
                    Text(configStore.configuration.useMockProviders
                         ? "Contra is using offline demo content — no network calls, no API key needed."
                         : "Contra never stores AI provider keys on this device. Requests are routed through your configured backend, which connects to your AI provider.")
                        .font(.system(size: 12))
                        .foregroundStyle(ContraTheme.textSecondary)

                    Toggle("Developer Mode", isOn: $showDeveloperMode)
                    if showDeveloperMode {
                        TextField("Backend URL (e.g. your Worker's .workers.dev URL)", text: $customEndpoint)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                if let url = URL(string: customEndpoint) {
                                    configStore.configuration.baseURL = url
                                }
                            }
                        SecureField("Your access code (from whoever set up the backend)", text: $sharedSecret)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                configStore.configuration.sharedSecret = sharedSecret
                            }
                        Text("Current: \(configStore.configuration.baseURL.absoluteString)")
                            .font(.system(size: 12))
                            .foregroundStyle(ContraTheme.textTertiary)
                        Text("Each person needs their own access code — it has its own daily limit. See backend/README.md.")
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
            .onAppear {
                customEndpoint = configStore.configuration.baseURL.absoluteString
                sharedSecret = configStore.configuration.sharedSecret
            }
        }
    }
}

#Preview {
    SettingsView()
}
