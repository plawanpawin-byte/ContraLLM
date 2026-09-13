//
//  VoiceView.swift
//  ContraLLM
//

import SwiftUI

struct VoiceView: View {
    let workspace: Workspace
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var speechViewModel = VoiceSpeechViewModel()
    @State private var draftText = ""

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
                    onSend: { chatViewModel.send($0) }
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(ContraTheme.background.ignoresSafeArea())
        .navigationTitle(workspace.title)
        .navigationBarTitleDisplayMode(.inline)
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
                    .symbolEffect(.variableColor.iterative, isActive: speechViewModel.isListening)
            }
            Text(workspace.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ContraTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
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
