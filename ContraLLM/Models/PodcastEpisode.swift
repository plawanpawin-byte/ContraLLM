//
//  PodcastEpisode.swift
//  ContraLLM
//

import Foundation

struct PodcastSpeaker: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let name: String
    let role: String // e.g. "Host", "Expert"
}

struct TranscriptLine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let speakerName: String
    let text: String
    let timestamp: TimeInterval
}

struct PodcastEpisode: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let title: String
    let durationSeconds: TimeInterval
    let audioURL: URL?
    let speakers: [PodcastSpeaker]
    let transcript: [TranscriptLine]
    let coverSymbol: String
}
