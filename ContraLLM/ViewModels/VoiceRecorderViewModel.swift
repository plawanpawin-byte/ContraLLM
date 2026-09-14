//
//  VoiceRecorderViewModel.swift
//  ContraLLM
//
//  Drives the Voice tab's record button: captures audio, then runs it
//  through the same real pipeline Home uses for any other source
//  (transcribe -> AI title -> AI notebook/summary) to produce a Workspace
//  marked as a recording (Workspace.recordingFileName set).
//

import Foundation
import AVFoundation
import SwiftData

@MainActor
final class VoiceRecorderViewModel: NSObject, ObservableObject {
    enum ProcessingState: Equatable {
        case idle
        case processing
        case failed(String)
    }

    @Published private(set) var isRecording = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var processingState: ProcessingState = .idle

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentURL: URL?

    private let aiChatService: AIChatService
    private let documentProcessingService: DocumentProcessingService

    init(
        aiChatService: AIChatService? = nil,
        documentProcessingService: DocumentProcessingService? = nil
    ) {
        self.aiChatService = aiChatService ?? ServiceContainer.shared.aiChatService
        self.documentProcessingService = documentProcessingService ?? ServiceContainer.shared.documentProcessingService
    }

    func toggleRecording(modelContext: ModelContext, onFinished: @escaping (Workspace?) -> Void) {
        if isRecording {
            stopAndProcess(modelContext: modelContext, onFinished: onFinished)
        } else {
            start()
        }
    }

    private func start() {
        Task {
            let session = AVAudioSession.sharedInstance()
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard granted else {
                processingState = .failed("Microphone access is required to record.")
                return
            }

            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true)

                let url = RecordingsStorage.newRecordingURL()
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                ]
                let recorder = try AVAudioRecorder(url: url, settings: settings)
                recorder.delegate = self
                recorder.record()

                self.recorder = recorder
                self.currentURL = url
                self.elapsedSeconds = 0
                self.isRecording = true
                self.processingState = .idle

                timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                    guard let self, let recorder = self.recorder else { return }
                    Task { @MainActor in self.elapsedSeconds = recorder.currentTime }
                }
            } catch {
                processingState = .failed("Couldn't start recording: \(error.localizedDescription)")
            }
        }
    }

    private func stopAndProcess(modelContext: ModelContext, onFinished: @escaping (Workspace?) -> Void) {
        guard let recorder, let url = currentURL else { return }
        let duration = recorder.currentTime
        recorder.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard duration >= 1 else {
            try? FileManager.default.removeItem(at: url)
            onFinished(nil)
            return
        }

        processingState = .processing
        Task {
            let workspace = await buildWorkspace(fileURL: url, duration: duration)
            if let workspace {
                modelContext.insert(workspace)
                try? modelContext.save()
            }
            processingState = .idle
            onFinished(workspace)
        }
    }

    private func buildWorkspace(fileURL: URL, duration: TimeInterval) async -> Workspace? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let displayName = "Recording \(formatter.string(from: Date()))"
        let source = SourceItem(type: .audio, displayName: displayName, localURL: fileURL)

        do {
            let content = try await documentProcessingService.process(source: source)
            let title = (try? await aiChatService.generateWorkspaceTitle(from: source, sourceText: content.sourceText))
                ?? displayName

            let workspace = Workspace(
                title: title,
                sourceDisplayName: displayName,
                sourceType: .audio,
                recordingFileName: fileURL.lastPathComponent,
                recordingDurationSeconds: duration
            )
            workspace.notebookData = try? JSONEncoder().encode(content.notebook)
            workspace.slidesData = try? JSONEncoder().encode(content.slides)
            workspace.sourceText = content.sourceText
            return workspace
        } catch {
            // Still keep the recording even if AI processing failed —
            // losing the actual audio the user just recorded would be worse.
            let workspace = Workspace(
                title: displayName,
                sourceDisplayName: displayName,
                sourceType: .audio,
                recordingFileName: fileURL.lastPathComponent,
                recordingDurationSeconds: duration
            )
            return workspace
        }
    }
}

extension VoiceRecorderViewModel: AVAudioRecorderDelegate {}
