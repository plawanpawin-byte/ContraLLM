//
//  VoiceRecordingsView.swift
//  ContraLLM
//
//  Top-level "Voice" tab: record a voice memo with the big red button, and
//  browse past recordings — each one auto-titled by AI from what you
//  actually said. Distinct from the per-workspace "Voice" chat screen
//  reached from a source's workspace grid.
//

import SwiftUI
import SwiftData

struct VoiceRecordingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var recorder = VoiceRecorderViewModel()
    @State private var failureAlertMessage: String?

    @Query(
        filter: #Predicate<Workspace> { $0.recordingFileName != nil },
        sort: \Workspace.createdAt,
        order: .reverse
    ) private var recordings: [Workspace]

    var body: some View {
        NavigationStack {
            ZStack {
                ContraTheme.background.ignoresSafeArea()

                if recordings.isEmpty && recorder.processingState == .idle && !recorder.isRecording {
                    EmptyStateView(
                        symbolName: "waveform",
                        title: "No recordings yet",
                        message: "Tap the red button to record a voice memo. AI will transcribe and summarize it automatically."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if recorder.processingState == .processing {
                                processingRow
                            }
                            ForEach(recordings) { workspace in
                                NavigationLink {
                                    VoiceRecordingDetailView(workspace: workspace)
                                } label: {
                                    RecordingRow(workspace: workspace)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 100) // clear the floating record button
                    }
                }

                VStack {
                    Spacer()
                    recordButton
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Voice")
            .onChange(of: recorder.processingState) { _, state in
                if case .failed(let message) = state { failureAlertMessage = message }
            }
            .alert(
                "Recording failed",
                isPresented: Binding(
                    get: { failureAlertMessage != nil },
                    set: { if !$0 { failureAlertMessage = nil } }
                ),
                presenting: failureAlertMessage
            ) { _ in
                Button("OK") {}
            } message: { message in
                Text(message)
            }
        }
    }

    private var processingRow: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Summarizing your recording…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ContraTheme.textSecondary)
            Spacer()
        }
        .padding(14)
        .contraCard(padding: 0)
        .padding(0)
    }

    private var recordButton: some View {
        Button {
            recorder.toggleRecording(modelContext: modelContext) { _ in
                // New recording appears via @Query automatically.
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: recorder.isRecording ? 72 : 64, height: recorder.isRecording ? 72 : 64)
                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                }
            }
            .shadow(color: Color.red.opacity(0.35), radius: 12, x: 0, y: 6)
            .overlay(alignment: .top) {
                if recorder.isRecording {
                    Text(timeString(recorder.elapsedSeconds))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ContraTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(ContraTheme.surfaceElevated)
                        .clipShape(Capsule())
                        .offset(y: -32)
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: recorder.isRecording)
        .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct RecordingRow: View {
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(ContraTheme.accentSoft)
                    .frame(width: 44, height: 44)
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ContraTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(workspace.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ContraTheme.textPrimary)
                    .lineLimit(2)
                Text("\(durationString) · \(workspace.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 12))
                    .foregroundStyle(ContraTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ContraTheme.textTertiary)
        }
        .padding(14)
        .contraCard(padding: 0)
        .padding(0)
    }

    private var durationString: String {
        let total = Int(workspace.recordingDurationSeconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
