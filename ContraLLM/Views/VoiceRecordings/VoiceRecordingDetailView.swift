//
//  VoiceRecordingDetailView.swift
//  ContraLLM
//
//  Play back a past recording, read its AI summary, and ask follow-up
//  questions grounded in the actual transcript.
//

import SwiftUI
import SwiftData

struct VoiceRecordingDetailView: View {
    let workspace: Workspace
    @Environment(\.modelContext) private var modelContext
    @StateObject private var playback = RecordingPlaybackViewModel()
    @StateObject private var chatViewModel: ChatViewModel
    @State private var blocks: [NotebookBlock] = []
    @State private var draftText = ""

    init(workspace: Workspace) {
        self.workspace = workspace
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(workspace: workspace))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    playbackCard

                    if !blocks.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("AI Summary")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ContraTheme.textPrimary)
                            ForEach(blocks) { block in
                                NotebookBlockView(block: block)
                            }
                        }
                        .padding(20)
                        .contraCard()
                    }
                }
                .padding(16)
            }

            if let last = chatViewModel.messages.last, last.role == .assistant {
                AIResponseBanner(message: last) {
                    chatViewModel.messages.removeAll { $0.id == last.id }
                }
                .padding(.bottom, 8)
            }

            AIPromptBar(
                text: $draftText,
                placeholder: "Ask about this recording…",
                isLoading: chatViewModel.isSending,
                quickActions: ["Summarize"],
                onSend: { chatViewModel.send($0, contextPrefix: "About this voice recording") }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(ContraTheme.background.ignoresSafeArea())
        .navigationTitle(workspace.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let fileName = workspace.recordingFileName {
                playback.load(fileName: fileName, fallbackDuration: workspace.recordingDurationSeconds)
            }
            if blocks.isEmpty, let data = workspace.notebookData {
                blocks = (try? JSONDecoder().decode([NotebookBlock].self, from: data)) ?? []
            }
            chatViewModel.attachModelContext(modelContext)
        }
        .onDisappear { playback.stop() }
    }

    private var playbackCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Button(action: playback.togglePlayback) {
                    Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(ContraTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ContraTheme.textPrimary)
                        .lineLimit(2)
                    Text(workspace.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(ContraTheme.textSecondary)
                }
                Spacer()
            }

            VStack(spacing: 4) {
                Slider(
                    value: Binding(get: { playback.currentTime }, set: { playback.seek(to: $0) }),
                    in: 0...max(playback.duration, 1)
                )
                .tint(ContraTheme.accent)

                HStack {
                    Text(timeString(playback.currentTime))
                    Spacer()
                    Text(timeString(playback.duration))
                }
                .font(.system(size: 11))
                .foregroundStyle(ContraTheme.textTertiary)
            }
        }
        .padding(16)
        .contraCard()
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
