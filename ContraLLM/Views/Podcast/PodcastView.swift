//
//  PodcastView.swift
//  ContraLLM
//

import SwiftUI
import SwiftData

struct PodcastView: View {
    let workspace: Workspace
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: PodcastViewModel
    @StateObject private var chatViewModel: ChatViewModel
    @State private var draftText = ""
    @State private var showVoicePicker = false

    init(workspace: Workspace) {
        self.workspace = workspace
        _viewModel = StateObject(wrappedValue: PodcastViewModel(workspace: workspace))
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(workspace: workspace))
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxHeight: .infinity)

            AskAIThread(messages: chatViewModel.messages) { chatViewModel.send($0) }

            AIPromptBar(
                text: $draftText,
                placeholder: "Ask about this episode…",
                isLoading: chatViewModel.isSending,
                quickActions: ["Summarize"],
                onSend: { chatViewModel.send($0, contextPrefix: "About the podcast") }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(ContraTheme.background.ignoresSafeArea())
        .navigationTitle("Podcast")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.generateIfNeeded()
            chatViewModel.attachModelContext(modelContext)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showVoicePicker = true
                } label: {
                    Image(systemName: "person.wave.2")
                }
                .accessibilityLabel("Choose narration voice")
            }
        }
        .sheet(isPresented: $showVoicePicker) {
            PodcastVoicePickerView()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .generating:
            LoadingView(
                headline: "Generating your podcast",
                steps: [
                    ProcessingStep(title: "Summarizing source"),
                    ProcessingStep(title: "Writing script"),
                    ProcessingStep(title: "Casting speakers"),
                    ProcessingStep(title: "Synthesizing audio")
                ],
                activeIndex: 2
            )
        case .failed(let message):
            EmptyStateView(
                symbolName: "waveform.slash",
                title: "Audio unavailable",
                message: message,
                actionTitle: "Try again",
                action: { viewModel.generateIfNeeded() }
            )
        case .ready(let episode):
            player(for: episode)
        }
    }

    private func player(for episode: PodcastEpisode) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(ContraTheme.accentSoft)
                        .frame(width: 180, height: 180)
                    Image(systemName: episode.coverSymbol)
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(ContraTheme.accent)
                }
                .padding(.top, 20)

                VStack(spacing: 4) {
                    Text(episode.title)
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text(episode.speakers.map(\.name).joined(separator: " & "))
                        .font(.system(size: 13))
                        .foregroundStyle(ContraTheme.textSecondary)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 6) {
                    Slider(value: Binding(
                        get: { viewModel.progressSeconds },
                        set: { viewModel.seek(to: $0) }
                    ), in: 0...episode.durationSeconds)
                    .tint(ContraTheme.accent)

                    HStack {
                        Text(timeString(viewModel.progressSeconds))
                        Spacer()
                        Text(timeString(episode.durationSeconds))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(ContraTheme.textTertiary)
                }
                .padding(.horizontal, 24)

                HStack(spacing: 32) {
                    Button {
                        viewModel.skip(-15, duration: episode.durationSeconds)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 22))
                    }
                    Button {
                        viewModel.togglePlayback()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 52))
                    }
                    Button {
                        viewModel.skip(15, duration: episode.durationSeconds)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 22))
                    }
                }
                .foregroundStyle(ContraTheme.textPrimary)

                if let current = viewModel.currentLine(in: episode) {
                    liveCaption(current)
                }

                transcript(for: episode)
                    .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
    }

    /// A single, clear, synced caption — updates as playback moves through
    /// the transcript's timestamps, like real podcast-app subtitles.
    private func liveCaption(_ line: TranscriptLine) -> some View {
        Text(line.text)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(ContraTheme.textPrimary)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 28)
            .padding(.vertical, 4)
            .frame(minHeight: 70)
            .animation(.easeInOut(duration: 0.2), value: line.id)
    }

    private func transcript(for episode: PodcastEpisode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Full transcript")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ContraTheme.textPrimary)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(episode.transcript) { line in
                    let isActive = viewModel.currentLine(in: episode)?.id == line.id
                    VStack(alignment: .leading, spacing: 3) {
                        Text(line.speakerName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ContraTheme.accent)
                        Text(line.text)
                            .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? ContraTheme.textPrimary : ContraTheme.textSecondary)
                    }
                    .padding(.horizontal, isActive ? 8 : 0)
                    .padding(.vertical, isActive ? 6 : 0)
                    .background(isActive ? ContraTheme.accentSoft : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(16)
            .contraCard()
            .padding(.horizontal, 16)
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
