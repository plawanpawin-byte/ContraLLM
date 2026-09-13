//
//  VoiceProfile.swift
//  ContraLLM
//

import Foundation

struct VoiceProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let name: String
    let accent: String
    let gender: String

    static let defaultProfile = VoiceProfile(name: "Contra", accent: "American English", gender: "Neutral")
}
