//
//  HomeViewModel.swift
//  ContraLLM
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var pendingSource: SourceItem?
    @Published var isImporterPresented = false
    @Published var importerContentTypes: [UTType] = [.pdf]
    @Published var errorMessage: String?

    func requestFileImport(for type: SourceType) {
        switch type {
        case .pdf:
            importerContentTypes = [.pdf]
        case .audio:
            importerContentTypes = [.mp3, .wav, .mpeg4Audio, .audio]
        case .text:
            importerContentTypes = [.plainText]
        case .document:
            importerContentTypes = [.pdf, .plainText, .rtf, .text]
        default:
            importerContentTypes = [.item]
        }
        isImporterPresented = true
    }

    /// Maps an imported file's URL/type to a SourceItem, or nil on failure.
    func handleFileImportResult(_ result: Result<[URL], Error>) -> SourceItem? {
        switch result {
        case .failure(let error):
            errorMessage = "Couldn't import that file: \(error.localizedDescription)"
            return nil
        case .success(let urls):
            guard let url = urls.first else {
                errorMessage = "No file was selected."
                return nil
            }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            let ext = url.pathExtension.lowercased()
            let type: SourceType
            switch ext {
            case "pdf": type = .pdf
            case "mp3", "wav", "m4a": type = .audio
            case "txt": type = .text
            default: type = .document
            }

            // The picker's URL is only readable while its security scope is
            // held (this call). Copy the file into our own sandbox now so
            // later async processing (Processing screen, real extraction)
            // can still read it after this scope closes.
            let persistedURL = copyIntoSandbox(url)

            return SourceItem(type: type, displayName: url.lastPathComponent, localURL: persistedURL ?? url)
        }
    }

    /// Parses free-form input text and returns a SourceItem if it's a URL,
    /// or a plain-text source otherwise.
    func makeSource(fromInput input: String) -> SourceItem {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if SourceURLClassifier.isLikelyURL(trimmed), let type = SourceURLClassifier.classify(trimmed) {
            let url = URL(string: trimmed)
            let displayName = url?.host ?? trimmed
            return SourceItem(type: type, displayName: displayName, remoteURL: url)
        }
        let displayName = String(trimmed.prefix(60))
        return SourceItem(type: .text, displayName: displayName.isEmpty ? "Pasted text" : displayName)
    }

    /// Copies an imported file into `Application Support/Sources`, returning
    /// the new persistent URL, or nil if the copy fails (caller falls back
    /// to the original URL — best-effort, not fatal).
    private func copyIntoSandbox(_ url: URL) -> URL? {
        let fileManager = FileManager.default
        guard let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let destinationDir = supportDir.appendingPathComponent("Sources", isDirectory: true)
        do {
            try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            let destination = destinationDir.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: url, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}
