//
//  MockDocumentProcessingService.swift
//  ContraLLM
//

import Foundation

final class MockDocumentProcessingService: DocumentProcessingService {
    func process(source: SourceItem) async throws -> ProcessedContent {
        try await Task.sleep(nanoseconds: 500_000_000)
        return ProcessedContent(
            notebook: MockContent.notebookBlocks(for: source),
            slides: MockContent.slides(for: source),
            sourceText: nil
        )
    }
}

/// Shared mock content generators used to seed both freshly-processed
/// sources and the demo library entry.
enum MockContent {

    static func notebookBlocks(for source: SourceItem) -> [NotebookBlock] {
        [
            NotebookBlock(kind: .heading, text: "Main Concept"),
            NotebookBlock(
                kind: .paragraph,
                text: "",
                spans: [
                    InlineSpan(text: "This source introduces a mechanism that lets a model relate every part of its input to every other part directly, rather than processing it strictly in order. The core idea is called "),
                    InlineSpan(text: "self-attention", bold: true, accent: true),
                    InlineSpan(text: ", and it changes how information flows through the system.")
                ]
            ),
            NotebookBlock(kind: .quote, text: "Attention allows the model to relate every token to other tokens in the sequence, regardless of distance."),
            NotebookBlock(
                kind: .definition,
                text: "A mechanism that lets each element in a sequence weigh the relevance of every other element when building its representation.",
                caption: "Self-Attention"
            ),
            NotebookBlock(
                kind: .paragraph,
                text: "",
                spans: [
                    InlineSpan(text: "Unlike sequential approaches, this method allows "),
                    InlineSpan(text: "parallel processing", underline: true),
                    InlineSpan(text: " across the entire input, which makes training significantly faster on modern hardware.")
                ]
            ),
            NotebookBlock(kind: .keyIdea, text: "Long-range relationships can be captured in a single step, without the information having to pass through many intermediate positions."),
            NotebookBlock(kind: .researchFinding, text: "Models built on this mechanism consistently outperform prior sequential architectures on large-scale benchmarks, while training in a fraction of the time.", caption: "Finding"),
            NotebookBlock(kind: .importantPoint, text: "The mechanism is the foundational building block behind most modern large language models."),
            NotebookBlock(kind: .citation, text: "\(source.displayName)", caption: "Source"),
            NotebookBlock(kind: .question, text: "How might this idea generalize beyond text to other kinds of sequential data?"),
            NotebookBlock(kind: .aiSummary, text: "In short: this source proposes a way for every part of the input to directly inform every other part, enabling faster training and stronger long-range understanding — the foundation of modern AI architectures.")
        ]
    }

    static func slides(for source: SourceItem) -> [Slide] {
        [
            Slide(
                title: "Overview",
                body: "This source explores a core idea that reshapes how information is processed and understood.",
                keyPoints: ["Introduces the central mechanism", "Explains why it matters", "Sets up deeper exploration"],
                quote: nil,
                symbolName: "sparkles",
                hasCitation: false
            ),
            Slide(
                title: "The Core Mechanism",
                body: "Self-attention lets the model relate every token to every other token in the sequence, regardless of distance.",
                keyPoints: ["Self Attention", "Parallel Processing", "Long-range Relationships"],
                quote: "Attention allows the model to relate every token to other tokens in the sequence.",
                symbolName: "point.3.filled.connected.trianglepath.dotted",
                hasCitation: true
            ),
            Slide(
                title: "Why Parallel Matters",
                body: "Because every position can be processed at once, training scales far more efficiently on modern hardware.",
                keyPoints: ["Faster training", "Better hardware utilization", "Scales to larger datasets"],
                quote: nil,
                symbolName: "bolt.horizontal.circle",
                hasCitation: false
            ),
            Slide(
                title: "Long-Range Understanding",
                body: "Distant parts of an input can directly influence each other in a single step, improving coherence over long sequences.",
                keyPoints: ["No information bottleneck", "Stronger context modeling"],
                quote: nil,
                symbolName: "arrow.left.and.right.circle",
                hasCitation: false
            ),
            Slide(
                title: "Real-World Impact",
                body: "This mechanism underlies most state-of-the-art language and multimodal models used today.",
                keyPoints: ["Foundation of modern LLMs", "Extends beyond text"],
                quote: nil,
                symbolName: "globe.americas.fill",
                hasCitation: true
            ),
            Slide(
                title: "Key Takeaway",
                body: "Understanding this one mechanism unlocks intuition for how most modern AI systems actually work.",
                keyPoints: ["A small idea with outsized impact"],
                quote: nil,
                symbolName: "checkmark.seal.fill",
                hasCitation: false
            )
        ]
    }

    static func sampleConversation(title: String) -> [AIMessage] {
        [
            AIMessage(role: .assistant, text: "I've read through your source. Ask me anything about \"\(title)\" — or try one of the suggestions below.", suggestedFollowUps: ["Explain this in simple terms", "What's the most important idea?", "Why does this matter?"]),
            AIMessage(role: .user, text: "Explain this in simple terms"),
            AIMessage(role: .assistant, text: "Think of it like a room full of people where everyone can talk to everyone else at once, instead of passing notes down a line. That's what makes this mechanism both fast and powerful.")
        ]
    }
}
