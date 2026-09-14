//
//  SlidesView.swift
//  ContraLLM
//

import SwiftUI

struct SlidesView: View {
    let workspace: Workspace
    @State private var slides: [Slide] = []
    @State private var currentIndex = 0
    @StateObject private var chatViewModel: ChatViewModel
    @State private var draftText = ""

    init(workspace: Workspace) {
        self.workspace = workspace
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(workspace: workspace))
    }

    var body: some View {
        VStack(spacing: 0) {
            if slides.isEmpty {
                EmptyStateView(
                    symbolName: "rectangle.stack.badge.minus",
                    title: "No slides yet",
                    message: "We couldn't generate slides for this source."
                )
                .frame(maxHeight: .infinity)
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                        SlideCardView(slide: slide, index: index, total: slides.count)
                            .tag(index)
                            .padding(.horizontal, 16)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                pageIndicator

                if let last = chatViewModel.messages.last, last.role == .assistant {
                    AIResponseBanner(message: last) {
                        chatViewModel.messages.removeAll { $0.id == last.id }
                    }
                    .padding(.bottom, 8)
                }

                AIPromptBar(
                    text: $draftText,
                    placeholder: "Ask about this slide…",
                    isLoading: chatViewModel.isSending,
                    quickActions: ["Summarize"],
                    onSend: { text in
                        let slideTitle = slides[currentIndex].title
                        chatViewModel.send(text, contextPrefix: "About slide \"\(slideTitle)\"")
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
        .background(ContraTheme.background.ignoresSafeArea())
        .navigationTitle("Slides")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if slides.isEmpty, let data = workspace.slidesData {
                slides = (try? JSONDecoder().decode([Slide].self, from: data)) ?? []
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<slides.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? ContraTheme.accent : ContraTheme.border)
                    .frame(width: index == currentIndex ? 18 : 6, height: 6)
                    .animation(.easeOut(duration: 0.2), value: currentIndex)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct SlideCardView: View {
    let slide: Slide
    let index: Int
    let total: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: slide.symbolName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(ContraTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(ContraTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Spacer()
                    Text("Slide \(index + 1) of \(total)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ContraTheme.textTertiary)
                    if slide.hasCitation {
                        Image(systemName: "quote.closing")
                            .font(.system(size: 12))
                            .foregroundStyle(ContraTheme.textTertiary)
                    }
                }

                Text(slide.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ContraTheme.textPrimary)

                Text(slide.body)
                    .font(.system(size: 15))
                    .foregroundStyle(ContraTheme.textSecondary)

                if let quote = slide.quote {
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle()
                            .fill(ContraTheme.accent)
                            .frame(width: 3)
                        Text(quote)
                            .font(.system(size: 14, weight: .medium).italic())
                            .foregroundStyle(ContraTheme.textPrimary)
                    }
                    .padding(.vertical, 4)
                }

                if !slide.keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Points")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ContraTheme.textTertiary)
                            .textCase(.uppercase)
                        ForEach(slide.keyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(ContraTheme.accent)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)
                                Text(point)
                                    .font(.system(size: 14))
                                    .foregroundStyle(ContraTheme.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .contraCard()
            .padding(.vertical, 12)
        }
    }
}
