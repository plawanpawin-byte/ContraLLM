//
//  ServiceContainer.swift
//  ContraLLM
//
//  Single place that wires concrete service implementations to the protocols
//  the rest of the app depends on. aiChatService and documentProcessingService
//  switch live between the Mock/* demo providers and the Backend/* real
//  implementations based on Settings → AI → "Use demo AI provider" — so
//  toggling it takes effect immediately, no relaunch needed.
//
//  speechToTextService is always the real on-device Apple Speech
//  implementation (free, no network/API key, works with the demo AI
//  provider too) — it defaults to Thai. Podcast and text-to-speech-to-file
//  stay mocked for now (see README "Known limitations"); live spoken
//  replies on the Voice tab use SpeechSpeaker directly, not this protocol.
//

import Foundation

@MainActor
final class ServiceContainer {
    static let shared = ServiceContainer()

    private let mockAIChatService = MockAIChatService()
    private let mockDocumentProcessingService = MockDocumentProcessingService()

    let podcastService: PodcastService = MockPodcastService()
    let speechToTextService: SpeechToTextService = RealSpeechToTextService()
    let textToSpeechService: TextToSpeechService = MockTextToSpeechService()

    private init() {}

    var aiChatService: AIChatService {
        let config = APIConfigurationStore.shared.configuration
        return config.useMockProviders ? mockAIChatService : BackendAIChatService(configuration: config)
    }

    var documentProcessingService: DocumentProcessingService {
        let config = APIConfigurationStore.shared.configuration
        return config.useMockProviders ? mockDocumentProcessingService : BackendDocumentProcessingService(configuration: config)
    }
}
