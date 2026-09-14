//
//  APIConfiguration.swift
//  ContraLLM
//
//  The iOS client never talks to an AI provider directly and never embeds a
//  secret API key. In production it calls the Contra backend / API gateway,
//  which in turn talks to whichever AI provider is configured server-side.
//
//      iPhone -> Contra Backend -> AI Provider
//
//  A developer-mode custom endpoint is supported for testing against a local
//  or staging backend.
//

import Foundation

struct APIConfiguration: Codable, Equatable {
    var baseURL: URL
    var useMockProviders: Bool
    /// Optional shared secret sent as `Authorization: Bearer <value>` on
    /// every backend request. Matches the Worker's `APP_SHARED_SECRET`, if
    /// the person hosting the backend set one. Never a provider API key.
    var sharedSecret: String

    static let `default` = APIConfiguration(
        baseURL: URL(string: "https://api.contrallm.app")!,
        useMockProviders: true,
        sharedSecret: ""
    )
}

@MainActor
final class APIConfigurationStore: ObservableObject {
    static let shared = APIConfigurationStore()

    @Published var configuration: APIConfiguration {
        didSet { persist() }
    }

    private let defaultsKey = "com.contra.llm.apiConfiguration"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(APIConfiguration.self, from: data) {
            configuration = decoded
        } else {
            configuration = .default
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
