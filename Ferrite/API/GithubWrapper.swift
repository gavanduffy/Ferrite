import Foundation

enum GithubError: Error {
    case InvalidUrl
}

class Github {
    func fetchLatestRelease() async throws -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/Ferrite-iOS/Ferrite/releases/latest") else { throw GithubError.InvalidUrl }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Release.self, from: data)
    }

    func fetchReleases() async throws -> [Release]? {
        guard let url = URL(string: "https://api.github.com/repos/Ferrite-iOS/Ferrite/releases") else { throw GithubError.InvalidUrl }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Release].self, from: data)
    }
}
