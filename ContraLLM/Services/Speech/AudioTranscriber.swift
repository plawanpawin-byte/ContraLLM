//
//  AudioTranscriber.swift
//  ContraLLM
//
//  Shared on-device transcription of an existing audio FILE (as opposed to
//  RealSpeechToTextService, which handles live microphone input). Used both
//  for imported audio sources and for recordings made in the Voice tab.
//  Free, no network/API key — Apple's Speech framework, Thai-preferred.
//

import Foundation
import Speech

enum AudioTranscriber {
    static func transcribe(fileAt url: URL) async -> String? {
        guard let recognizer = preferredRecognizer(), recognizer.isAvailable else { return nil }

        let authorized = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard authorized else { return nil }

        let request = SFSpeechURLRecognitionRequest(url: url)
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            recognizer.recognitionTask(with: request) { result, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let result, result.isFinal else { return }
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }

    /// Prefers Thai, falls back to the device's current locale, then en-US.
    static func preferredRecognizer() -> SFSpeechRecognizer? {
        if let thai = SFSpeechRecognizer(locale: Locale(identifier: "th-TH")), thai.isAvailable {
            return thai
        }
        if let device = SFSpeechRecognizer(locale: Locale.current), device.isAvailable {
            return device
        }
        return SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
}
