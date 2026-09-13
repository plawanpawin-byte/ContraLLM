//
//  AIResponseBanner.swift
//  ContraLLM
//
//  Compact inline AI reply, shown above the prompt bar on surfaces (Podcast,
//  Slides, Notebook) that don't have a full chat transcript.
//

import SwiftUI

struct AIResponseBanner: View {
    let message: AIMessage
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundStyle(ContraTheme.accent)
                .padding(.top, 2)

            if message.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Thinking…")
                        .font(.system(size: 13))
                        .foregroundStyle(ContraTheme.textSecondary)
                }
            } else {
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(ContraTheme.textPrimary)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ContraTheme.textTertiary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(ContraTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ContraTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
