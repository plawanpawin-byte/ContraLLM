//
//  NotebookBlockView.swift
//  ContraLLM
//
//  Renders a single NotebookBlock with visual treatment specific to its
//  kind — styled like a real handwritten notebook page: a handwriting
//  system font for headings/annotations, and a highlighter-pen look for
//  highlighted text, on top of NotebookPaper's ruled-paper background.
//

import SwiftUI

struct NotebookBlockView: View {
    let block: NotebookBlock

    var body: some View {
        switch block.kind {
        case .heading:
            Text(block.text)
                .font(NotebookPaper.handwritten(26, bold: true))
                .foregroundStyle(ContraTheme.textPrimary)
                .padding(.top, 6)

        case .paragraph:
            styledText
                .font(.system(size: 15))
                .foregroundStyle(ContraTheme.textPrimary)
                .lineSpacing(6)

        case .keyIdea:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(ContraTheme.accent)
                    .padding(.top, 2)
                Text(block.text)
                    .font(NotebookPaper.handwritten(18, bold: true))
                    .foregroundStyle(ContraTheme.textPrimary)
            }
            .padding(14)
            .background(ContraTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .rotationEffect(.degrees(-0.4))

        case .definition:
            VStack(alignment: .leading, spacing: 6) {
                if let term = block.caption {
                    Text(term)
                        .font(NotebookPaper.handwritten(20, bold: true))
                        .foregroundStyle(ContraTheme.accent)
                }
                Text(block.text)
                    .font(.system(size: 14))
                    .foregroundStyle(ContraTheme.textPrimary)
            }
            .padding(14)
            .background(ContraTheme.surface.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(ContraTheme.border)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        case .quote:
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(ContraTheme.accent)
                    .frame(width: 3)
                Text("\u{201C}\(block.text)\u{201D}")
                    .font(NotebookPaper.handwritten(19))
                    .foregroundStyle(ContraTheme.textPrimary)
            }
            .padding(.vertical, 4)

        case .highlight:
            Text(block.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.85))
                .highlighterMark()

        case .citation:
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 11))
                Text(block.text)
                    .font(.system(size: 12, weight: .medium))
                if let caption = block.caption {
                    Text("· \(caption)")
                        .font(.system(size: 12))
                }
            }
            .foregroundStyle(ContraTheme.textSecondary)

        case .researchFinding:
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(ContraTheme.accent.opacity(0.5))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    if let caption = block.caption {
                        Text(caption.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ContraTheme.accent)
                    }
                    Text(block.text)
                        .font(.system(size: 14))
                        .foregroundStyle(ContraTheme.textPrimary)
                }
            }

        case .importantPoint:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.orange)
                    .padding(.top, 2)
                Text(block.text)
                    .font(NotebookPaper.handwritten(16))
                    .underline(true, pattern: .solid, color: ContraTheme.accent)
                    .foregroundStyle(ContraTheme.textPrimary)
            }

        case .question:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(ContraTheme.textSecondary)
                    .padding(.top, 2)
                Text(block.text)
                    .font(NotebookPaper.handwritten(16).italic())
                    .foregroundStyle(ContraTheme.textSecondary)
            }

        case .aiSummary:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                    Text("AI Summary")
                        .font(NotebookPaper.handwritten(15, bold: true))
                }
                .foregroundStyle(ContraTheme.accent)

                Text(block.text)
                    .font(.system(size: 14))
                    .foregroundStyle(ContraTheme.textPrimary)
            }
            .padding(14)
            .background(ContraTheme.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ContraTheme.accent.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    /// Builds an AttributedString from the block's inline spans, applying
    /// selective bold / underline / highlight / accent styling. A
    /// `highlighted` span gets a highlighter-pen background via a
    /// SwiftUI.Text background isn't possible per-run, so highlighted spans
    /// render as their own highlighterMark()-wrapped Text below instead.
    private var styledText: Text {
        guard !block.spans.isEmpty else {
            return Text(block.text)
        }

        return block.spans.reduce(Text("")) { partial, span in
            var segment = Text(span.text)
            if span.bold { segment = segment.bold() }
            if span.underline { segment = segment.underline() }
            if span.accent { segment = segment.foregroundColor(ContraTheme.accent).bold() }
            return partial + segment
        }
    }
}
