//
//  AskAIThread.swift
//  ContraLLM
//
//  A proper scrollable chat thread (sent message + AI reply, both as real
//  message bubbles) for surfaces that have a prompt bar but aren't a full
//  dedicated chat screen (Podcast, Slides, Notebook) — replaces the old
//  single-reply AIResponseBanner, which only ever showed the latest AI
//  answer and never what the user actually sent.
//

import SwiftUI

struct AskAIThread: View {
    let messages: [AIMessage]
    var onFollowUp: (String) -> Void

    var body: some View {
        if !messages.isEmpty {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message, onFollowUp: onFollowUp)
                                .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 280)
                .background(ContraTheme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: ContraTheme.cardRadius, style: .continuous)
                        .stroke(ContraTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: ContraTheme.cardRadius, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onAppear {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
