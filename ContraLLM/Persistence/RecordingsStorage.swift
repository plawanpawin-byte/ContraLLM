//
//  RecordingsStorage.swift
//  ContraLLM
//
//  Where Voice-tab recordings live on disk. Workspace.recordingFileName only
//  stores the filename; this resolves it to a full URL.
//

import Foundation

enum RecordingsStorage {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func newRecordingURL() -> URL {
        directory.appendingPathComponent("\(UUID().uuidString).m4a")
    }

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }
}
