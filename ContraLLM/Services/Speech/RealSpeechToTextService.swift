//
//  RealSpeechToTextService.swift
//  ContraLLM
//
//  On-device speech recognition via Apple's Speech framework. Defaults to
//  Thai (th-TH) so the mic button works for Thai speech out of the box,
//  falling back to the device's current locale, then en-US, if a Thai
//  recognizer isn't available. Free, no network/API key required — this is
//  always the live implementation, not gated behind the demo/backend toggle.
//

import Foundation
import Speech
import AVFoundation

final class RealSpeechToTextService: NSObject, SpeechToTextService {
    private(set) var isListening: Bool = false

    private var recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latestTranscript = ""

    func startListening() async throws {
        guard !isListening else { return }

        try await requestPermissions()

        let recognizer = AudioTranscriber.preferredRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            throw AIServiceError.invalidResponse
        }
        self.recognizer = recognizer

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        latestTranscript = ""

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            self.latestTranscript = result.bestTranscription.formattedString
        }
    }

    func stopListening() async throws -> String {
        guard isListening else { return "" }
        isListening = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        request = nil
        task = nil

        return latestTranscript
    }

    private func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            throw AIServiceError.unauthorized
        }

        let micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else {
            throw AIServiceError.unauthorized
        }
    }
}
