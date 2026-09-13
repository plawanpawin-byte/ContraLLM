//
//  PodcastService.swift
//  ContraLLM
//
//  Provider-independent abstraction for turning a Workspace's source into a
//  generated podcast episode (Summary -> Outline -> Script -> Speakers -> TTS -> Audio).
//

import Foundation

protocol PodcastService {
    func generatePodcast(for workspace: Workspace) async throws -> PodcastEpisode
}
