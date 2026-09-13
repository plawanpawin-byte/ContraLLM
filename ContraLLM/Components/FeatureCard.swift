//
//  FeatureCard.swift
//  ContraLLM
//
//  One of the 4 cards on the Workspace screen: Voice, Podcast, Slides, Notebook.
//

import SwiftUI

struct FeatureCard: View {
    let symbolName: String
    let title: String
    let description: String
    var isPressed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbolName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ContraTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(ContraTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ContraTheme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ContraTheme.textPrimary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(ContraTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .contraCard()
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.12), value: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(title)")
    }
}

/// Button wrapper adding a native press-down feel without extra dependencies.
struct FeatureCardButton: View {
    let symbolName: String
    let title: String
    let description: String
    let action: () -> Void

    @GestureState private var isPressed = false

    var body: some View {
        FeatureCard(symbolName: symbolName, title: title, description: description, isPressed: isPressed)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
            )
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        FeatureCardButton(symbolName: "waveform", title: "Voice", description: "Talk with AI and explore the story behind your source.", action: {})
        FeatureCardButton(symbolName: "headphones", title: "Podcast", description: "Turn your source into an engaging audio story.", action: {})
    }
    .padding()
    .background(ContraTheme.background)
}
