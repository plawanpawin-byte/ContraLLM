//
//  WorkspaceView.swift
//  ContraLLM
//

import SwiftUI

enum WorkspaceDestination: Hashable {
    case voice
    case podcast
    case slides
    case notebook
}

struct WorkspaceView: View {
    @Bindable var workspace: Workspace
    @State private var destination: WorkspaceDestination?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    FeatureCardButton(
                        symbolName: "waveform",
                        title: "Voice",
                        description: "Talk with AI and explore the story behind your source through a natural conversation.",
                        action: { destination = .voice }
                    )
                    FeatureCardButton(
                        symbolName: "headphones",
                        title: "Podcast",
                        description: "Turn your source into an engaging audio story or a conversation between AI hosts.",
                        action: { destination = .podcast }
                    )
                    FeatureCardButton(
                        symbolName: "rectangle.stack",
                        title: "Slides",
                        description: "Learn the key ideas as a clean, visual sequence of AI-generated slides.",
                        action: { destination = .slides }
                    )
                    FeatureCardButton(
                        symbolName: "note.text",
                        title: "Notebook",
                        description: "Read AI-organized notes with key ideas, highlights, definitions, and important evidence.",
                        action: { destination = .notebook }
                    )
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
        .background(ContraTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .voice: VoiceView(workspace: workspace)
            case .podcast: PodcastView(workspace: workspace)
            case .slides: SlidesView(workspace: workspace)
            case .notebook: NotebookView(workspace: workspace)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(workspace.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(ContraTheme.textPrimary)

            HStack(spacing: 6) {
                Image(systemName: workspace.sourceType.symbolName)
                    .font(.system(size: 12))
                Text(workspace.sourceDisplayName)
                    .lineLimit(1)
                Text("·")
                Text(workspace.sourceType.displayName)
            }
            .font(.system(size: 13))
            .foregroundStyle(ContraTheme.textSecondary)
        }
        .padding(.horizontal, 16)
    }
}
