//
//  TextToSpeechService.swift
//  ContraLLM
//
//  Provider-independent abstraction for speech synthesis. Used by Voice and
//  Podcast generation. A production implementation might wrap AVSpeechSynthesizer,
//  ElevenLabs, or a backend TTS endpoint.
//

import Foundation

protocol TextToSpeechService {
    func synthesize(text: String, voice: VoiceProfile) async throws -> URL
}
