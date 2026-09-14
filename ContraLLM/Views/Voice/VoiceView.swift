//
//  VoiceView.swift
//  ContraLLM
//

import SwiftUI
import SwiftData

struct VoiceView: View {
    let workspace: Workspace
    @Environment(\.modelContext) private var modelContext
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var speechViewModel = VoiceSpeechViewModel()
    @StateObject private var speaker = SpeechSpeaker()
    @State private var draftText = ""
    @State private var autoSpeakEnabled = true
    @State private var lastSpokenMessageID: UUID?

    init(workspace: Workspace) {
        self.workspace = workspace
        let initial = MockContent.sampleConversation(title: workspace.title)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(workspace: workspace, initialMessages: initial))
    }

    var body: some View {
        VStack(spacing: 0) {
            orb

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(chatViewModel.messages) { message in
                            ChatBubble(message: message) { followUp in
                                chatViewModel.send(followUp)
                            }
                            .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: chatViewModel.messages.count) { _, _ in
                    if let last = chatViewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                // The loading placeholder is swapped for the real reply
                // without changing messages.count, so speak once sending
                // finishes rather than on count changes.
                .onChange(of: chatViewModel.isSending) { _, isSending in
                    if !isSending { speakLatestReplyIfNeeded() }
                }
            }

            VStack(spacing: 10) {
                Button {
                    speechViewModel.toggleListening { transcript in
                        chatViewModel.send(transcript)
                    }
                } label: {
                    Image(systemName: speechViewModel.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(speechViewModel.isListening ? .white : ContraTheme.accent)
                        .frame(width: 52, height: 52)
                        .background(speechViewModel.isListening ? ContraTheme.accent : ContraTheme.accentSoft)
                        .clipShape(Circle())
                }
                .accessibilityLabel(speechViewModel.isListening ? "Stop listening" : "Start voice input")

                AIPromptBar(
                    text: $draftText,
                    placeholder: "Explain this in simple terms…",
                    isLoading: chatViewModel.isSending,
                    quickActions: ["Summarize"],
                    onSend: { chatViewModel.send($0) }
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(ContraTheme.background.ignoresSafeArea())
        .navigationTitle(workspace.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { chatViewModel.attachModelContext(modelContext) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    autoSpeakEnabled.toggle()
                    if !autoSpeakEnabled { speaker.stop() }
                } label: {
                    Image(systemName: autoSpeakEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .accessibilityLabel(autoSpeakEnabled ? "Spoken replies on" : "Spoken replies off")
            }
        }
    }

    private var orb: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(ContraTheme.accentSoft)
                    .frame(width: 64, height: 64)
                Image(systemName: "waveform")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(ContraTheme.accent)
                    .symbolEffect(.variableColor.iterative, isActive: speechViewModel.isListening || speaker.isSpeaking)
            }
            Text(workspace.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ContraTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    /// Speaks a freshly-arrived assistant reply aloud (Thai text gets a Thai
    /// voice automatically — see SpeechSpeaker). Skips messages already
    /// spoken and anything still streaming/loading.
    private func speakLatestReplyIfNeeded() {
        guard autoSpeakEnabled,
              let last = chatViewModel.messages.last,
              last.role == .assistant,
              !last.isLoading,
              last.id != lastSpokenMessageID else { return }
        lastSpokenMessageID = last.id
        speaker.speak(last.text)
    }
}

/// Thin wrapper around SpeechToTextService to drive the mic button's UI state.
@MainActor
final class VoiceSpeechViewModel: ObservableObject {
    @Published var isListening = false
    private let service: SpeechToTextService = ServiceContainer.shared.speechToTextService

    func toggleListening(onTranscript: @escaping (String) -> Void) {
        if isListening {
            Task {
                let transcript = try? await service.stopListening()
                isListening = false
                if let transcript, !transcript.isEmpty {
                    onTranscript(transcript)
                }
            }
        } else {
            Task {
                try? await service.startListening()
                isListening = true
            }
        }
    }
}
