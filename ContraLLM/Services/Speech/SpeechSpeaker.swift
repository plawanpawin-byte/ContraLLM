//
//  SpeechSpeaker.swift
//  ContraLLM
//
//  Lightweight live speech-out helper for the Voice tab — speaks an AI
//  reply aloud immediately via AVSpeechSynthesizer, picking a Thai voice
//  automatically when the text is Thai. Separate from TextToSpeechService
//  (which renders podcast audio to a file); this one just talks.
//

import Foundation
import AVFoundation

@MainActor
final class SpeechSpeaker: ObservableObject {
    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SpeechSpeakerDelegate()

    init() {
        synthesizer.delegate = delegate
        delegate.onFinish = { [weak self] in self?.isSpeaking = false }
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.voice(for: trimmed)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    /// Picks a Thai voice when the text is (mostly) Thai script, otherwise
    /// lets AVSpeechSynthesisVoice fall back to the device's default.
    private static func voice(for text: String) -> AVSpeechSynthesisVoice? {
        let isThai = text.unicodeScalars.contains { (0x0E00...0x0E7F).contains($0.value) }
        if isThai, let thaiVoice = AVSpeechSynthesisVoice(language: "th-TH") {
            return thaiVoice
        }
        return AVSpeechSynthesisVoice(language: Locale.current.identifier)
    }
}

private final class SpeechSpeakerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
