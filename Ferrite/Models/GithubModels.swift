//
//  GithubModels.swift
//  Ferrite
//
//  Created by Brian Dashore on 8/28/22.
//

import Foundation

extension Github {
    enum GithubError: Error {
        case invalidUrl
        case decodeError
        case networkError
    }

    struct Release: Codable, Hashable, Sendable {
        let htmlUrl: String
        let tagName: String

        enum CodingKeys: String, CodingKey {
            case htmlUrl = "html_url"
            case tagName = "tag_name"
        }
    }
}
