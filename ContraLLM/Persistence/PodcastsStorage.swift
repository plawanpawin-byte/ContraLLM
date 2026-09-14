//
//  PodcastsStorage.swift
//  ContraLLM
//
//  Where generated podcast audio files live on disk, keyed by workspace id
//  so re-opening a workspace reuses the same rendered episode.
//

import Foundation

enum PodcastsStorage {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Podcasts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for workspaceID: UUID) -> URL {
        directory.appendingPathComponent("\(workspaceID.uuidString).caf")
    }
}
