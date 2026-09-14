//
//  AIPromptBar.swift
//  ContraLLM
//
//  Reusable "Ask AI" input used across Voice, Podcast, Slides and Notebook.
//  For the Home screen's source-adding bar, see SourceInputBar.
//

import SwiftUI

struct AIPromptBar: View {
    @Binding var text: String
    var placeholder: String = "Ask a question…"
    var isLoading: Bool = false
    /// Short labels shown as tappable chips above the input, e.g. ["Summarize"].
    /// Tapping one sends its label as a message immediately.
    var quickActions: [String] = []
    var onSend: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !quickActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickActions, id: \.self) { action in
                            Button {
                                onSend(action)
                            } label: {
                                Text(action)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ContraTheme.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(ContraTheme.accentSoft)
                                    .clipShape(Capsule())
                            }
                            .disabled(isLoading)
                        }
                    }
                }
            }
            inputRow
        }
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .focused($isFocused)
                .disabled(isLoading)
                .accessibilityLabel("Ask AI")

            Button(action: send) {
                Group {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .frame(width: 30, height: 30)
                .foregroundStyle(.white)
                .background(canSend ? ContraTheme.accent : ContraTheme.textTertiary)
                .clipShape(Circle())
            }
            .disabled(!canSend || isLoading)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ContraTheme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: ContraTheme.controlRadius, style: .continuous)
                .stroke(isFocused ? ContraTheme.accent.opacity(0.5) : ContraTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ContraTheme.controlRadius, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        onSend(value)
        text = ""
        isFocused = false
    }
}

#Preview {
    AIPromptBar(text: .constant(""), onSend: { _ in })
        .padding()
}
