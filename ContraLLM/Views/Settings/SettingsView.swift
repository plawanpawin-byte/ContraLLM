//
//  SettingsView.swift
//  ContraLLM
//

import SwiftUI

private enum ConnectionTestState: Equatable {
    case idle
    case testing
    case success(label: String?)
    case failure(String)
}

struct SettingsView: View {
    @StateObject private var configStore = APIConfigurationStore.shared
    @State private var showDeveloperMode = false
    @State private var customEndpoint = ""
    @State private var sharedSecret = ""
    @State private var connectionTest: ConnectionTestState = .idle
    @AppStorage(AppStorageKey.themeMode) private var themeModeRaw: String = AppThemeMode.system.rawValue
    @AppStorage(AppStorageKey.displayName) private var displayName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(ContraTheme.accentSoft)
                                .frame(width: 48, height: 48)
                            Text(profileInitials)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(ContraTheme.accent)
                        }
                        TextField("Your name", text: $displayName)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .padding(.vertical, 4)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $themeModeRaw) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

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

                        Button(action: testConnection) {
                            HStack(spacing: 8) {
                                if connectionTest == .testing {
                                    ProgressView()
                                }
                                Text("Test Connection")
                            }
                        }
                        .disabled(connectionTest == .testing)

                        connectionTestStatus
                    }
                }

                Section("Voice") {
                    NavigationLink {
                        PodcastVoicePickerView()
                    } label: {
                        Label("Podcast narration voice", systemImage: "waveform")
                    }
                    Text("Speech recognition (mic) and podcast narration both run on-device via Apple's Speech and Speech Synthesis frameworks — Thai-preferred, free, no API key.")
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

    private var profileInitials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "🙂" }
        let words = trimmed.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    @ViewBuilder
    private var connectionTestStatus: some View {
        switch connectionTest {
        case .idle:
            EmptyView()
        case .testing:
            EmptyView()
        case .success(let label):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(label.map { "Connected as \($0)" } ?? "Connected")
            }
            .font(.system(size: 12, weight: .medium))
        case .failure(let message):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text(message)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.red)
        }
    }

    private func testConnection() {
        // Make sure we're testing whatever's currently typed in the fields,
        // not stale committed values the user hasn't hit return on yet.
        if let url = URL(string: customEndpoint) {
            configStore.configuration.baseURL = url
        }
        configStore.configuration.sharedSecret = sharedSecret

        connectionTest = .testing
        let client = BackendAPIClient(configuration: configStore.configuration)
        Task {
            struct VerifyResponse: Decodable { let ok: Bool; let label: String? }
            do {
                let result: VerifyResponse = try await client.get(path: "/v1/verify")
                connectionTest = result.ok ? .success(label: result.label) : .failure("Backend responded but did not confirm.")
            } catch let error as AIServiceError {
                connectionTest = .failure(error.errorDescription ?? "Connection failed.")
            } catch {
                connectionTest = .failure("Couldn't reach the backend.")
            }
        }
    }
}

#Preview {
    SettingsView()
}
