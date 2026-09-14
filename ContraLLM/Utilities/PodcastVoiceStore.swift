//
//  PodcastVoiceStore.swift
//  ContraLLM
//
//  User-selectable narration voice for generated podcasts (Settings ->
//  Voice). Stores an AVSpeechSynthesisVoice identifier; "Automatic" (empty
//  string) lets RealPodcastService pick a Thai/English voice based on the
//  script's language.
//

import Foundation
import AVFoundation

enum PodcastVoiceStore {
    static let storageKey = "com.contra.llm.podcastVoiceIdentifier"

    struct Option: Identifiable, Hashable {
        let identifier: String // empty = automatic
        let label: String
        var id: String { identifier }
    }

    /// A curated, de-duplicated list: "Automatic" first, then every
    /// installed Thai and English voice, best quality first.
    static func availableOptions() -> [Option] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("th") || $0.language.hasPrefix("en") }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality.rawValue > rhs.quality.rawValue }
                return lhs.name < rhs.name
            }

        var seenNames = Set<String>()
        let deduped = voices.filter { seenNames.insert("\($0.name)-\($0.language)").inserted }

        let options = deduped.map { voice in
            Option(identifier: voice.identifier, label: "\(voice.name) (\(voice.language))")
        }
        return [Option(identifier: "", label: "Automatic")] + options
    }

    static func resolveVoice(forLanguageSample text: String) -> AVSpeechSynthesisVoice? {
        let stored = UserDefaults.standard.string(forKey: storageKey) ?? ""
        if !stored.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: stored) {
            return voice
        }
        let isThai = text.unicodeScalars.contains { (0x0E00...0x0E7F).contains($0.value) }
        return AVSpeechSynthesisVoice(language: isThai ? "th-TH" : "en-US")
    }
}
