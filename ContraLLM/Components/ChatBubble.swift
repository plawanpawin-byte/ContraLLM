//
//  ChatBubble.swift
//  ContraLLM
//
//  Shared chat message rendering used by Voice and any Ask-AI transcript.
//

import SwiftUI

struct ChatBubble: View {
    let message: AIMessage
    var onFollowUp: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            bubble
            if !message.citations.isEmpty {
                HStack(spacing: 6) {
                    ForEach(message.citations) { citation in
                        HStack(spacing: 4) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 10))
                            Text(citation.label)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(ContraTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ContraTheme.surface)
                        .clipShape(Capsule())
                    }
                }
            }
            if !message.suggestedFollowUps.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(message.suggestedFollowUps, id: \.self) { suggestion in
                            Button {
                                onFollowUp?(suggestion)
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(ContraTheme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(ContraTheme.accentSoft)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    @ViewBuilder
    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if message.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Thinking…")
                        .font(.system(size: 14))
                        .foregroundStyle(ContraTheme.textSecondary)
                }
            } else {
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundStyle(message.role == .user ? .white : ContraTheme.textPrimary)
                }
                ForEach(message.bulletPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        Text(point)
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(message.role == .user ? .white.opacity(0.9) : ContraTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(message.role == .user ? ContraTheme.accent : ContraTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: 300, alignment: message.role == .user ? .trailing : .leading)
    }
}
