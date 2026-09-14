//
//  ServiceContainer.swift
//  ContraLLM
//
//  Single place that wires concrete service implementations to the protocols
//  the rest of the app depends on. aiChatService and documentProcessingService
//  switch live between the Mock/* demo providers and the Backend/* real
//  implementations based on Settings → AI → "Use demo AI provider" — so
//  toggling it takes effect immediately, no relaunch needed. Podcast and
//  speech services stay mocked for now (see README "Known limitations").
//

import Foundation

@MainActor
final class ServiceContainer {
    static let shared = ServiceContainer()

    private let mockAIChatService = MockAIChatService()
    private let mockDocumentProcessingService = MockDocumentProcessingService()

    let podcastService: PodcastService = MockPodcastService()
    let speechToTextService: SpeechToTextService = MockSpeechToTextService()
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
