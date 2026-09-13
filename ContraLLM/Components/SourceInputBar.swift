//
//  SourceInputBar.swift
//  ContraLLM
//
//  The Home screen's "Source Prompt Bar" — used to add a new source, not to
//  chat with AI. Supports file import (+ menu) and pasted URLs.
//

import SwiftUI
import UniformTypeIdentifiers

struct SourceInputBar: View {
    @Binding var text: String
    var isBusy: Bool = false
    var onPickFileType: (SourceType) -> Void
    var onSubmitURLOrText: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Button { onPickFileType(.pdf) } label: { Label("PDF", systemImage: "doc.richtext") }
                Button { onPickFileType(.document) } label: { Label("Document", systemImage: "doc.text") }
                Button { onPickFileType(.audio) } label: { Label("Audio", systemImage: "waveform") }
                Button { onPickFileType(.text) } label: { Label("Text", systemImage: "text.alignleft") }
                Button { isFocused = true } label: { Label("Link", systemImage: "link") }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ContraTheme.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(ContraTheme.surface)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Add a source")
            .disabled(isBusy)

            TextField("Add a file, link, video, or audio…", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(size: 15))
                .focused($isFocused)
                .disabled(isBusy)
                .submitLabel(.go)
                .onSubmit(submit)
                .accessibilityLabel("Add a source by link or text")

            Button(action: submit) {
                Group {
                    if isBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .frame(width: 32, height: 32)
                .foregroundStyle(.white)
                .background(canSubmit ? ContraTheme.accent : ContraTheme.textTertiary)
                .clipShape(Circle())
            }
            .disabled(!canSubmit || isBusy)
            .accessibilityLabel("Continue")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ContraTheme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isFocused ? ContraTheme.accent.opacity(0.5) : ContraTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        onSubmitURLOrText(value)
        text = ""
        isFocused = false
    }
}

/// Compact quick-action chips shown near the Source Prompt Bar.
struct QuickSourceChips: View {
    var onSelect: (SourceType) -> Void

    private let items: [(SourceType, String)] = [
        (.pdf, "PDF"),
        (.youtube, "YouTube"),
        (.website, "Website"),
        (.audio, "Audio"),
        (.googleDocs, "Google Docs")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    Button {
                        onSelect(item.0)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.0.symbolName)
                                .font(.system(size: 12, weight: .medium))
                            Text(item.1)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(ContraTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(ContraTheme.surface)
                        .overlay(
                            Capsule().stroke(ContraTheme.border, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Add \(item.1) source")
                }
            }
        }
    }
}
