//
//  MockPodcastService.swift
//  ContraLLM
//

import Foundation

final class MockPodcastService: PodcastService {
    func generatePodcast(for workspace: Workspace) async throws -> PodcastEpisode {
        try await Task.sleep(nanoseconds: 600_000_000)

        let speakers = [
            PodcastSpeaker(name: "Ava", role: "Host"),
            PodcastSpeaker(name: "Milo", role: "Expert")
        ]

        let transcript: [TranscriptLine] = [
            TranscriptLine(speakerName: "Ava", text: "Welcome back — today we're digging into \"\(workspace.title)\".", timestamp: 0),
            TranscriptLine(speakerName: "Milo", text: "It's a fascinating topic. The core idea really reframes how we think about the problem.", timestamp: 8),
            TranscriptLine(speakerName: "Ava", text: "Let's start with the basics — what's the big picture here?", timestamp: 16),
            TranscriptLine(speakerName: "Milo", text: "At its heart, the source lays out a mechanism that's both simple and surprisingly powerful.", timestamp: 24),
            TranscriptLine(speakerName: "Ava", text: "And that's exactly why this is worth understanding deeply.", timestamp: 34)
        ]

        return PodcastEpisode(
            title: "\(workspace.title): The Breakdown",
            durationSeconds: 8 * 60 + 42,
            audioURL: nil,
            speakers: speakers,
            transcript: transcript,
            coverSymbol: "waveform.circle.fill"
        )
    }
}
