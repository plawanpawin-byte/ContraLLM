//
//  PodcastViewModel.swift
//  ContraLLM
//

import Foundation
import AVFoundation

@MainActor
final class PodcastViewModel: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case generating
        case ready(PodcastEpisode)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var isPlaying = false
    @Published var progressSeconds: TimeInterval = 0

    private let workspace: Workspace
    private let podcastService: PodcastService
    private var player: AVAudioPlayer?
    private var timer: Timer?

    init(workspace: Workspace, podcastService: PodcastService? = nil) {
        self.workspace = workspace
        self.podcastService = podcastService ?? ServiceContainer.shared.podcastService
    }

    func generateIfNeeded() {
        guard case .idle = state else { return }
        Task {
            state = .generating
            do {
                let episode = try await podcastService.generatePodcast(for: workspace)
                preparePlayer(for: episode)
                state = .ready(episode)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func preparePlayer(for episode: PodcastEpisode) {
        guard let audioURL = episode.audioURL, FileManager.default.fileExists(atPath: audioURL.path) else {
            return // mock/demo episode with no real audio file — controls stay UI-only
        }
        player = try? AVAudioPlayer(contentsOf: audioURL)
        player?.delegate = self
        player?.prepareToPlay()
    }

    func togglePlayback() {
        guard let player else {
            isPlaying.toggle() // no real audio (demo mode) — just flip the icon
            return
        }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.progressSeconds = self?.player?.currentTime ?? 0 }
            }
        }
    }

    func seek(to seconds: TimeInterval) {
        progressSeconds = seconds
        player?.currentTime = seconds
    }

    func skip(_ delta: TimeInterval, duration: TimeInterval) {
        seek(to: min(max(0, progressSeconds + delta), duration))
    }

    /// The transcript line whose timestamp has most recently passed — used
    /// to show a single clear, synced caption instead of the whole list.
    func currentLine(in episode: PodcastEpisode) -> TranscriptLine? {
        episode.transcript.last { $0.timestamp <= progressSeconds } ?? episode.transcript.first
    }
}

extension PodcastViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.timer?.invalidate()
        }
    }
}
