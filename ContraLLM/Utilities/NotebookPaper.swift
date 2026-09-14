//
//  NotebookPaper.swift
//  ContraLLM
//
//  "Handwritten notebook" look for the Notebook tab: a warm paper
//  background with faint ruled lines and a margin line, plus a handwriting
//  system font (Noteworthy, built into iOS) for headings/annotations —
//  makes the AI notes read more like a real notebook page than a generic card.
//

import SwiftUI

enum NotebookPaper {
    static let background = Color(light: 0xFFFDF6, dark: 0x1E1C17)
    static let ruleLine = Color(light: 0xE7DFC8, dark: 0x322E22)
    static let marginLine = Color(light: 0xE7AFAF, dark: 0x5C3636)

    static func handwritten(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Noteworthy-Bold" : "Noteworthy-Light", size: size)
    }
}

/// Draws faint horizontal rule lines and a left margin line, like ruled
/// notebook paper, behind whatever content is placed on top.
private struct RuledPaperBackground: View {
    var lineSpacing: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = lineSpacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(NotebookPaper.ruleLine), lineWidth: 1)
                y += lineSpacing
            }

            var margin = Path()
            let marginX: CGFloat = 28
            margin.move(to: CGPoint(x: marginX, y: 0))
            margin.addLine(to: CGPoint(x: marginX, y: size.height))
            context.stroke(margin, with: .color(NotebookPaper.marginLine), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}

struct NotebookPaperCard: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .padding(.leading, 12) // clear the margin line
            .background(
                ZStack {
                    NotebookPaper.background
                    RuledPaperBackground()
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: ContraTheme.cardRadius, style: .continuous)
                    .stroke(ContraTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: ContraTheme.cardRadius, style: .continuous))
            .shadow(color: ContraTheme.shadow, radius: 12, x: 0, y: 4)
    }
}

extension View {
    func notebookPaper(padding: CGFloat = 20) -> some View {
        modifier(NotebookPaperCard(padding: padding))
    }
}

/// A highlighter-pen style background behind a run of text — a slightly
/// rotated, softly-edged color bar, like an actual highlighter stroke.
struct HighlighterBackground: ViewModifier {
    var color: Color = Color.yellow.opacity(0.55)

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .rotationEffect(.degrees(-0.6))
            )
    }
}

extension View {
    func highlighterMark(_ color: Color = Color.yellow.opacity(0.55)) -> some View {
        modifier(HighlighterBackground(color: color))
    }
}
