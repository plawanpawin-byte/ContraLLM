//
//  RealPodcastService.swift
//  ContraLLM
//
//  Real PodcastService: asks the backend for a casual, storytelling
//  narration script grounded in the workspace's source, then renders it to
//  an actual audio file on-device with AVSpeechSynthesizer (free, works
//  offline once generated, Thai-capable) — no ElevenLabs/OpenAI TTS key
//  needed. Caches the result on the workspace so reopening it doesn't
//  re-generate or re-synthesize.
//

import Foundation
import AVFoundation

/// Guards a continuation against being resumed more than once — the write
/// callback below can, in principle, be invoked again after what looked
/// like the terminal buffer; this makes that a no-op instead of a crash.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func resume(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        action()
    }
}

final class RealPodcastService: PodcastService {
    private let client: BackendAPIClient

    init(configuration: APIConfiguration) {
        self.client = BackendAPIClient(configuration: configuration)
    }

    func generatePodcast(for workspace: Workspace) async throws -> PodcastEpisode {
        if let cached = cachedEpisode(for: workspace) {
            return cached
        }

        guard let sourceText = workspace.sourceText, sourceText.count >= 20 else {
            throw AIServiceError.invalidResponse
        }

        struct Req: Encodable { let sourceName: String; let sourceType: String; let sourceText: String }
        struct Res: Decodable { let title: String; let segments: [String] }

        let res: Res = try await client.post(
            path: "/v1/podcast",
            body: Req(sourceName: workspace.sourceDisplayName, sourceType: workspace.sourceType.rawValue, sourceText: sourceText),
            timeout: 60
        )

        let voice = PodcastVoiceStore.resolveVoice(forLanguageSample: res.segments.joined())
        let outputURL = PodcastsStorage.url(for: workspace.id)
        let (transcript, duration) = try await synthesize(segments: res.segments, voice: voice, to: outputURL)

        let episode = PodcastEpisode(
            title: res.title,
            durationSeconds: duration,
            audioURL: outputURL,
            speakers: [PodcastSpeaker(name: voice?.name ?? "Narrator", role: "Host")],
            transcript: transcript,
            coverSymbol: "waveform.circle.fill"
        )

        workspace.podcastData = try? JSONEncoder().encode(episode)
        return episode
    }

    private func cachedEpisode(for workspace: Workspace) -> PodcastEpisode? {
        guard let data = workspace.podcastData,
              let episode = try? JSONDecoder().decode(PodcastEpisode.self, from: data),
              let audioURL = episode.audioURL,
              FileManager.default.fileExists(atPath: audioURL.path) else {
            return nil
        }
        return episode
    }

    /// Renders each script segment to PCM via AVSpeechSynthesizer and
    /// appends it into one continuous audio file, recording each segment's
    /// start time so the UI can show synced captions.
    private func synthesize(
        segments: [String],
        voice: AVSpeechSynthesisVoice?,
        to outputURL: URL
    ) async throws -> ([TranscriptLine], TimeInterval) {
        let synthesizer = AVSpeechSynthesizer()
        var audioFile: AVAudioFile?
        var frameCount: Int64 = 0
        var sampleRate: Double = 22_050
        var lines: [TranscriptLine] = []
        let speakerName = voice?.name ?? "Narrator"

        try? FileManager.default.removeItem(at: outputURL)

        for segment in segments {
            let startSeconds = Double(frameCount) / sampleRate
            lines.append(TranscriptLine(speakerName: speakerName, text: segment, timestamp: startSeconds))

            let utterance = AVSpeechUtterance(string: segment)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.97 // clear, unhurried pacing

            let resumeBox = ResumeOnce()
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                synthesizer.write(utterance) { buffer in
                    guard let pcmBuffer = buffer as? AVAudioPCMBuffer, pcmBuffer.frameLength > 0 else {
                        // Non-PCM or the terminal empty buffer — either way this
                        // utterance has nothing more to give us.
                        resumeBox.resume { continuation.resume() }
                        return
                    }

                    if audioFile == nil {
                        sampleRate = pcmBuffer.format.sampleRate
                        audioFile = try? AVAudioFile(forWriting: outputURL, settings: pcmBuffer.format.settings)
                    }
                    try? audioFile?.write(from: pcmBuffer)
                    frameCount += Int64(pcmBuffer.frameLength)
                }
            }
        }

        let totalDuration = Double(frameCount) / sampleRate
        guard audioFile != nil, totalDuration > 0 else {
            throw AIServiceError.invalidResponse
        }
        return (lines, totalDuration)
    }
}
