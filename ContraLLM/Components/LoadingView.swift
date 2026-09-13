//
//  LoadingView.swift
//  ContraLLM
//
//  Shared processing/loading presentation used by the Processing screen and
//  any inline generation states (e.g. Podcast generation).
//

import SwiftUI

struct ProcessingStep: Identifiable, Equatable {
    let id = UUID()
    let title: String
}

struct LoadingView: View {
    let headline: String
    let steps: [ProcessingStep]
    let activeIndex: Int

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(ContraTheme.accentSoft)
                    .frame(width: 96, height: 96)
                    .scaleEffect(pulse ? 1.08 : 0.92)
                    .opacity(pulse ? 0.6 : 1)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(ContraTheme.accent)
            }
            .onAppear { pulse = true }

            Text(headline)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(ContraTheme.textPrimary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 12) {
                        stepIcon(for: index)
                            .frame(width: 20)
                        Text(step.title)
                            .font(.system(size: 15, weight: index == activeIndex ? .semibold : .regular))
                            .foregroundStyle(index <= activeIndex ? ContraTheme.textPrimary : ContraTheme.textTertiary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func stepIcon(for index: Int) -> some View {
        if index < activeIndex {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ContraTheme.accent)
        } else if index == activeIndex {
            ProgressView()
                .controlSize(.small)
        } else {
            Circle()
                .stroke(ContraTheme.border, lineWidth: 1.5)
                .frame(width: 16, height: 16)
        }
    }
}

#Preview {
    LoadingView(
        headline: "Analyzing your source",
        steps: [
            ProcessingStep(title: "Reading source"),
            ProcessingStep(title: "Extracting content"),
            ProcessingStep(title: "Understanding key ideas"),
            ProcessingStep(title: "Creating your workspace"),
            ProcessingStep(title: "Creating learning formats")
        ],
        activeIndex: 1
    )
}
