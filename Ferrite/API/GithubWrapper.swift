//
//  GithubWrapper.swift
//  Ferrite
//
//  Created by Brian Dashore on 8/28/22.
//

import Foundation

class Github {
    func fetchLatestRelease() async throws -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/Ferrite-iOS/Ferrite/releases/latest") else {
            throw GithubError.invalidUrl
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let rawResponse = try JSONDecoder().decode(Release.self, from: data)
            return rawResponse
        } catch {
            throw GithubError.networkError(description: error.localizedDescription)
        }
    }

    func fetchReleases() async throws -> [Release]? {
        guard let url = URL(string: "https://api.github.com/repos/Ferrite-iOS/Ferrite/releases") else {
            throw GithubError.invalidUrl
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let rawResponse = try JSONDecoder().decode([Release].self, from: data)
            return rawResponse
        } catch {
            throw GithubError.networkError(description: error.localizedDescription)
        }
    }
}
