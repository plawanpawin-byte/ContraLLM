//
//  BackendDocumentProcessingService.swift
//  ContraLLM
//
//  Real DocumentProcessingService implementation. Extracts plain text for
//  every source type, then asks the Contra backend to turn that text into
//  notebook blocks + slides grounded in the actual source:
//    - PDF: PDFKit, on-device
//    - Text/document files: read directly, on-device
//    - Website: fetch + strip HTML, on-device
//    - YouTube: fetch the watch page + captions track, on-device (this must
//      run on-device rather than on the backend — YouTube blocks Cloudflare
//      Workers' IP ranges for this, but not normal client requests)
//    - Google Docs: backend fetches the doc's public text export
//      (docs.google.com/.../export?format=txt) — requires the doc be shared
//      as "Anyone with the link can view"
//    - Audio (mp3/wav/m4a): on-device Apple Speech transcription of the
//      imported file (prefers Thai, see RealSpeechToTextService)
//

import Foundation
import PDFKit
import Speech

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

        case .youtube:
            guard let url = source.remoteURL else { return nil }
            return await fetchYouTubeTranscript(url)

        case .googleDocs:
            guard let url = source.remoteURL else { return nil }
            return await fetchGoogleDocsText(url)

        case .audio:
            guard let url = source.localURL else { return nil }
            return await transcribeAudioFile(url)
        }
    }

    // MARK: - YouTube (on-device — Cloudflare Workers get blocked by YouTube for this)

    private func fetchYouTubeTranscript(_ url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        guard let tracksRange = html.range(of: "\"captionTracks\":") else { return nil }
        let afterKey = html[tracksRange.upperBound...]
        guard let arrayEnd = afterKey.range(of: "]") else { return nil }
        let arrayJSON = String(afterKey[afterKey.startIndex...arrayEnd.lowerBound])

        guard let jsonData = arrayJSON.data(using: .utf8),
              let tracks = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]],
              !tracks.isEmpty else {
            return nil
        }

        let preferred = tracks.first { ($0["languageCode"] as? String) == "th" }
            ?? tracks.first { ($0["languageCode"] as? String)?.hasPrefix("en") == true }
            ?? tracks[0]

        guard let baseURLString = preferred["baseUrl"] as? String,
              let captionURL = URL(string: baseURLString) else {
            return nil
        }

        guard let (captionData, captionResponse) = try? await URLSession.shared.data(from: captionURL),
              let captionHTTP = captionResponse as? HTTPURLResponse, (200..<300).contains(captionHTTP.statusCode),
              let xml = String(data: captionData, encoding: .utf8) else {
            return nil
        }

        let lines = xml.matches(of: /<text[^>]*>([\s\S]*?)<\/text>/).map { match -> String in
            let raw = String(match.1)
            let stripped = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            return decodeHTMLEntities(stripped)
        }
        let transcript = lines.joined(separator: " ")
        return transcript.isEmpty ? nil : normalized(transcript)
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    // MARK: - Google Docs (via backend — plain doc export isn't blocked like YouTube is)

    private func fetchGoogleDocsText(_ url: URL) async -> String? {
        struct Req: Encodable { let sourceType: String; let sourceURL: String }
        struct Res: Decodable { let sourceText: String? }
        guard let res: Res = try? await client.post(
            path: "/v1/extract",
            body: Req(sourceType: "googleDocs", sourceURL: url.absoluteString),
            timeout: 30
        ) else { return nil }
        return res.sourceText.map(normalized)
    }

    // MARK: - Audio (on-device Apple Speech transcription)

    private func transcribeAudioFile(_ url: URL) async -> String? {
        guard let recognizer = Self.preferredRecognizer(), recognizer.isAvailable else { return nil }

        let authorized = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard authorized else { return nil }

        let request = SFSpeechURLRecognitionRequest(url: url)
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            recognizer.recognitionTask(with: request) { result, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let result, result.isFinal else { return }
                continuation.resume(returning: self.normalized(result.bestTranscription.formattedString))
            }
        }
    }

    private static func preferredRecognizer() -> SFSpeechRecognizer? {
        if let thai = SFSpeechRecognizer(locale: Locale(identifier: "th-TH")), thai.isAvailable {
            return thai
        }
        if let device = SFSpeechRecognizer(locale: Locale.current), device.isAvailable {
            return device
        }
        return SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
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
