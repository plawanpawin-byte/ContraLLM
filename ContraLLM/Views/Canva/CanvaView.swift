//
//  CanvaView.swift
//  ContraLLM
//
//  Standalone tab introducing a (not-yet-real) Canva integration. The "Link
//  your Canva now" button is UI-only for now — it doesn't perform any OAuth
//  flow or network call, it just simulates a short connect then shows
//  "Connected". Wiring a real Canva Connect API integration is a natural
//  next step, not implemented yet.
//

import SwiftUI
import AVKit

private enum CanvaLinkState: Equatable {
    case notLinked
    case linking
    case linked
}

struct CanvaView: View {
    @State private var linkState: CanvaLinkState = .notLinked
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 8)

                demoVideo
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: ContraTheme.cardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ContraTheme.cardRadius, style: .continuous)
                            .stroke(ContraTheme.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                Image("CanvaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: ContraTheme.shadow, radius: 12, x: 0, y: 4)

                VStack(spacing: 6) {
                    Text("Canva")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ContraTheme.textPrimary)
                    Text("Turn any workspace into a designed presentation, one tap away.")
                        .font(.system(size: 14))
                        .foregroundStyle(ContraTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                linkButton

                Spacer()
            }
            .navigationTitle("Canva")
            .navigationBarTitleDisplayMode(.inline)
            .background(ContraTheme.background.ignoresSafeArea())
            .onAppear(perform: enterTab)
            .onDisappear(perform: leaveTab)
        }
    }

    @ViewBuilder
    private var demoVideo: some View {
        if let player {
            VideoPlayer(player: player)
                .disabled(true) // decorative — no playback controls
        } else {
            RoundedRectangle(cornerRadius: ContraTheme.cardRadius, style: .continuous)
                .fill(ContraTheme.surface)
                .overlay(ProgressView())
        }
    }

    private var linkButton: some View {
        Button(action: linkTapped) {
            HStack(spacing: 8) {
                switch linkState {
                case .notLinked:
                    Text("Link your Canva now")
                case .linking:
                    ProgressView()
                        .tint(.white)
                    Text("Linking…")
                case .linked:
                    Image(systemName: "checkmark.circle.fill")
                    Text("Connected")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(linkState == .linked ? Color.green : ContraTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: ContraTheme.controlRadius, style: .continuous))
        }
        .disabled(linkState != .notLinked)
        .padding(.horizontal, 24)
    }

    private func linkTapped() {
        guard linkState == .notLinked else { return }
        linkState = .linking
        Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            linkState = .linked
        }
    }

    /// Called when this tab becomes the visible one. Sound only plays while
    /// the user is actually looking at this tab.
    private func enterTab() {
        preparePlayerIfNeeded()
        player?.isMuted = false
        player?.play()
    }

    /// Called when the user navigates away from this tab — stop the sound
    /// immediately rather than letting it keep playing in the background.
    private func leaveTab() {
        player?.pause()
        player?.isMuted = true
    }

    private func preparePlayerIfNeeded() {
        guard player == nil, let url = Bundle.main.url(forResource: "canva-demo", withExtension: "mp4") else { return }
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        player = queuePlayer
    }
}

#Preview {
    CanvaView()
}
