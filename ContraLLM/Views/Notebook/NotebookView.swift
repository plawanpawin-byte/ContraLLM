//
//  NotebookView.swift
//  ContraLLM
//

import SwiftUI

struct NotebookView: View {
    let workspace: Workspace
    @State private var blocks: [NotebookBlock] = []
    @StateObject private var chatViewModel: ChatViewModel
    @State private var draftText = ""

    init(workspace: Workspace) {
        self.workspace = workspace
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(workspace: workspace))
    }

    var body: some View {
        VStack(spacing: 0) {
            if blocks.isEmpty {
                EmptyStateView(
                    symbolName: "note.text.badge.plus",
                    title: "No notes yet",
                    message: "We couldn't generate notes for this source."
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(blocks) { block in
                            NotebookBlockView(block: block)
                        }
                    }
                    .padding(20)
                    .contraCard()
                    .padding(16)
                }
            }

            if let last = chatViewModel.messages.last, last.role == .assistant {
                AIResponseBanner(message: last) {
                    chatViewModel.messages.removeAll { $0.id == last.id }
                }
                .padding(.bottom, 8)
            }

            AIPromptBar(
                text: $draftText,
                placeholder: "Ask about your notes…",
                isLoading: chatViewModel.isSending,
                onSend: { chatViewModel.send($0, contextPrefix: "About the notebook") }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(ContraTheme.background.ignoresSafeArea())
        .navigationTitle("Notebook")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if blocks.isEmpty, let data = workspace.notebookData {
                blocks = (try? JSONDecoder().decode([NotebookBlock].self, from: data)) ?? []
            }
        }
    }
}
