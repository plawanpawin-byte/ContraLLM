//
//  PodcastViewModel.swift
//  ContraLLM
//

import Foundation

@MainActor
final class PodcastViewModel: ObservableObject {
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

    init(workspace: Workspace, podcastService: PodcastService = ServiceContainer.shared.podcastService) {
        self.workspace = workspace
        self.podcastService = podcastService
    }

    func generateIfNeeded() {
        guard case .idle = state else { return }
        Task {
            state = .generating
            do {
                let episode = try await podcastService.generatePodcast(for: workspace)
                state = .ready(episode)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func togglePlayback() {
        isPlaying.toggle()
    }

    func seek(to seconds: TimeInterval) {
        progressSeconds = seconds
    }

    func skip(_ delta: TimeInterval, duration: TimeInterval) {
        progressSeconds = min(max(0, progressSeconds + delta), duration)
    }
}
