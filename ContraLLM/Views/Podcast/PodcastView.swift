//
//  PodcastView.swift
//  ContraLLM
//

import SwiftUI

struct PodcastView: View {
    let workspace: Workspace
    @StateObject private var viewModel: PodcastViewModel
    @StateObject private var chatViewModel: ChatViewModel
    @State private var draftText = ""

    init(workspace: Workspace) {
        self.workspace = workspace
        _viewModel = StateObject(wrappedValue: PodcastViewModel(workspace: workspace))
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(workspace: workspace))
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxHeight: .infinity)

            if let last = chatViewModel.messages.last, last.role == .assistant {
                AIResponseBanner(message: last) {
                    chatViewModel.messages.removeAll { $0.id == last.id }
                }
                .padding(.bottom, 8)
            }

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
        .onAppear { viewModel.generateIfNeeded() }
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

                transcript(for: episode)
                    .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
    }

    private func transcript(for episode: PodcastEpisode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transcript")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ContraTheme.textPrimary)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(episode.transcript) { line in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(line.speakerName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ContraTheme.accent)
                        Text(line.text)
                            .font(.system(size: 14))
                            .foregroundStyle(ContraTheme.textPrimary)
                    }
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
