//
//  PodcastVoicePickerView.swift
//  ContraLLM
//
//  Lets the user pick which on-device voice narrates generated podcasts.
//  Reachable from the Podcast tab's toolbar and from Settings -> Voice.
//

import SwiftUI
import AVFoundation

struct PodcastVoicePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PodcastVoiceStore.storageKey) private var selectedIdentifier: String = ""
    @State private var options: [PodcastVoiceStore.Option] = []
    @State private var previewSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            List(options) { option in
                Button {
                    selectedIdentifier = option.identifier
                } label: {
                    HStack {
                        Text(option.label)
                            .foregroundStyle(ContraTheme.textPrimary)
                        Spacer()
                        if option.identifier == selectedIdentifier {
                            Image(systemName: "checkmark")
                                .foregroundStyle(ContraTheme.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button {
                        preview(option)
                    } label: {
                        Label("Preview", systemImage: "play.fill")
                    }
                    .tint(ContraTheme.accent)
                }
            }
            .navigationTitle("Narration Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { options = PodcastVoiceStore.availableOptions() }
        }
    }

    private func preview(_ option: PodcastVoiceStore.Option) {
        let utterance = AVSpeechUtterance(string: "Hi, this is how I'll sound narrating your podcasts.")
        utterance.voice = option.identifier.isEmpty
            ? AVSpeechSynthesisVoice(language: "en-US")
            : AVSpeechSynthesisVoice(identifier: option.identifier)
        previewSynthesizer.speak(utterance)
    }
}

#Preview {
    PodcastVoicePickerView()
}
