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
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let rawResponse = try JSONDecoder().decode(Release.self, from: data)
        return rawResponse
    }

    func fetchReleases() async throws -> [Release]? {
        guard let url = URL(string: "https://api.github.com/repos/Ferrite-iOS/Ferrite/releases") else {
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let rawResponse = try JSONDecoder().decode([Release].self, from: data)
        return rawResponse
    }
}
