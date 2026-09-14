//
//  BackendDocumentProcessingService.swift
//  ContraLLM
//
//  Real DocumentProcessingService implementation. Extracts plain text
//  on-device where possible (PDF via PDFKit, plain text files, a lightweight
//  HTML strip for websites), then asks the Contra backend to turn that text
//  into notebook blocks + slides grounded in the actual source.
//
//  YouTube, Google Docs, and audio sources don't have a reliable on-device
//  extraction path yet (transcript fetch / speech-to-text), so those fall
//  back to the same demo content MockDocumentProcessingService uses — real
//  extraction for those is a natural next step, not wired yet.
//

import Foundation
import PDFKit

final class BackendDocumentProcessingService: DocumentProcessingService {
    private let client: BackendAPIClient
    private let fallback = MockDocumentProcessingService()

    init(configuration: APIConfiguration) {
        self.client = BackendAPIClient(configuration: configuration)
    }

    func process(source: SourceItem) async throws -> ProcessedContent {
        guard let sourceText = await extractText(from: source), sourceText.count >= 20 else {
            // No extractable text (unsupported source type, empty file, or a
            // fetch failure) — keep the app usable with demo content instead
            // of hard-failing the whole processing flow.
            return try await fallback.process(source: source)
        }

        do {
            struct Req: Encodable { let sourceName: String; let sourceType: String; let sourceText: String }
            struct BlockRes: Decodable { let kind: String; let text: String; let caption: String? }
            struct SlideRes: Decodable {
                let title: String; let body: String; let keyPoints: [String]
                let quote: String?; let hasCitation: Bool
            }
            struct Res: Decodable { let notebook: [BlockRes]; let slides: [SlideRes] }

            let res: Res = try await client.post(
                path: "/v1/process",
                body: Req(sourceName: source.displayName, sourceType: source.type.rawValue, sourceText: sourceText),
                timeout: 60
            )

            let notebook = res.notebook.compactMap { block -> NotebookBlock? in
                guard let kind = NotebookBlockKind(rawValue: block.kind) else { return nil }
                return NotebookBlock(kind: kind, text: block.text, caption: block.caption)
            }

            let symbols = ["sparkles", "point.3.filled.connected.trianglepath.dotted", "bolt.horizontal.circle",
                            "arrow.left.and.right.circle", "globe.americas.fill", "checkmark.seal.fill", "lightbulb.fill"]
            let slides = res.slides.enumerated().map { index, slide in
                Slide(
                    title: slide.title,
                    body: slide.body,
                    keyPoints: slide.keyPoints,
                    quote: slide.quote,
                    symbolName: symbols[index % symbols.count],
                    hasCitation: slide.hasCitation
                )
            }

            guard !notebook.isEmpty, !slides.isEmpty else {
                return try await fallback.process(source: source)
            }

            return ProcessedContent(notebook: notebook, slides: slides, sourceText: sourceText)
        } catch {
            // Backend unreachable/misconfigured — don't strand the user on a
            // failed Processing screen, degrade to demo content instead.
            return try await fallback.process(source: source)
        }
    }

    // MARK: - Text extraction

    private func extractText(from source: SourceItem) async -> String? {
        switch source.type {
        case .pdf:
            guard let url = source.localURL, let document = PDFDocument(url: url) else { return nil }
            var text = ""
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                text += (page.string ?? "") + "\n"
            }
            return normalized(text)

        case .text, .document:
            guard let url = source.localURL, let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return normalized(raw)

        case .website:
            guard let url = source.remoteURL else { return nil }
            return await fetchAndStripHTML(url)

        case .youtube, .googleDocs, .audio:
            // Needs transcript fetch / speech-to-text — not wired yet.
            return nil
        }
    }

    private func fetchAndStripHTML(_ url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        var stripped = html
        for pattern in ["<script[\\s\\S]*?</script>", "<style[\\s\\S]*?</style>", "<!--[\\s\\S]*?-->"] {
            stripped = stripped.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        stripped = stripped.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        stripped = stripped
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")

        return normalized(stripped)
    }

    private func normalized(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Backend also truncates, but cap here too to keep uploads small.
        return String(collapsed.prefix(20_000))
    }
}
