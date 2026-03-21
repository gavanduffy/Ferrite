//
//  AllDebridWrapper.swift
//  Ferrite
//
//  Created by Brian Dashore on 11/25/22.
//

import Foundation

class AllDebrid: PollingDebridSource, ObservableObject {
    let id = "AllDebrid"
    let abbreviation = "AD"
    let website = "https://alldebrid.com"
    let description: String? = "AllDebrid is a debrid service that is used for downloads and media playback. " +
        "You must pay to access this service. \n\n" +
        "It is not recommended to use this service since media cache checks are not possible via the API. " +
        "Ferrite's instant availability solely looks at a user's magnet library. \n\n" +
        "If you must use this service, it is recommended to download search results manually using the context menu. \n\n" +
        "This service does not inform if a magnet link is a batch before downloading."

    let cachedStatus: [String] = ["Ready"]
    var authTask: Task<Void, Error>?

    @Published var authProcessing: Bool = false
    var isLoggedIn: Bool {
        getToken() != nil
    }

    var manualToken: String? {
        if UserDefaults.standard.bool(forKey: "AllDebrid.UseManualKey") {
            return getToken()
        } else {
            return nil
        }
    }

    @Published var IAValues: [DebridIA] = []
    @Published var cloudDownloads: [DebridCloudDownload] = []
    @Published var cloudMagnets: [DebridCloudMagnet] = []
    var cloudTTL: Double = 0.0

    private let baseApiUrl = "https://api.alldebrid.com/v4"
    private let appName = "Ferrite"

    private let jsonDecoder = JSONDecoder()

    init() {
        // Populate user downloads and magnets
        Task {
            try? await getUserDownloads()
            try? await getUserMagnets()
        }
    }

    // MARK: - Auth

    // Fetches information for PIN auth
    func getAuthUrl() async throws -> URL {
        let url = try buildRequestURL(urlString: "\(baseApiUrl)/pin/get")
        let request = URLRequest(url: url)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            // Validate the URL before doing anything else
            let rawResponse = try jsonDecoder.decode(ADResponse<PinResponse>.self, from: data).data
            guard let userUrl = URL(string: rawResponse.userURL) else {
                throw DebridError.AuthQuery(description: "The login URL is invalid")
            }

            // Spawn the polling task separately
            authTask = Task {
                try await getApiKey(checkID: rawResponse.check, pin: rawResponse.pin)
            }

            return userUrl
        } catch {
            print("Couldn't get pin information!")
            throw DebridError.AuthQuery(description: error.localizedDescription)
        }
    }

    // Fetches API keys
    func getApiKey(checkID: String, pin: String) async throws {
        let queryItems = [
            URLQueryItem(name: "agent", value: appName),
            URLQueryItem(name: "check", value: checkID),
            URLQueryItem(name: "pin", value: pin)
        ]

        let request = try URLRequest(url: buildRequestURL(urlString: "\(baseApiUrl)/pin/check", queryItems: queryItems))

        // Timer to poll AD API for key
        authTask = Task {
            var count = 0

            while count < 12 {
                if Task.isCancelled {
                    throw DebridError.AuthQuery(description: "Token request cancelled.")
                }

                let (data, _) = try await URLSession.shared.data(for: request)

                // We don't care if this fails
                let rawResponse = try? self.jsonDecoder.decode(ADResponse<ApiKeyResponse>.self, from: data).data

                // If there's an API key from the response, end the task successfully
                if let apiKeyResponse = rawResponse {
                    FerriteKeychain.shared.set(apiKeyResponse.apikey, forKey: "AllDebrid.ApiKey")

                    return
                } else {
                    try await Task.sleep(seconds: 5)
                    count += 1
                }
            }

            throw DebridError.AuthQuery(description: "Could not fetch the client ID and secret in time. Try logging in again.")
        }

        if case let .failure(error) = await authTask?.result {
            throw error
        }
    }

    // Adds a manual API key instead of web auth
    func setApiKey(_ key: String) {
        FerriteKeychain.shared.set(key, forKey: "AllDebrid.ApiKey")
        UserDefaults.standard.set(true, forKey: "AllDebrid.UseManualKey")
    }

    func getToken() -> String? {
        FerriteKeychain.shared.get("AllDebrid.ApiKey")
    }

    // Clears tokens. No endpoint to deregister a device
    func logout() {
        FerriteKeychain.shared.delete("AllDebrid.ApiKey")
        UserDefaults.standard.removeObject(forKey: "AllDebrid.UseManualKey")
    }

    // MARK: - Common request

    // Wrapper request function which matches the responses and returns data
    @discardableResult private func performRequest(request: inout URLRequest, requestName: String) async throws -> Data {
        guard let token = getToken() else {
            throw DebridError.InvalidToken
        }

        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw DebridError.FailedRequest(description: "No HTTP response given")
        }

        if response.statusCode >= 200, response.statusCode <= 299 {
            return data
        } else if response.statusCode == 401 {
            throw DebridError.FailedRequest(description: "The request \(requestName) failed because you were unauthorized. Please relogin to AllDebrid in Settings.")
        } else {
            throw DebridError.FailedRequest(description: "The request \(requestName) failed with status code \(response.statusCode).")
        }
    }

    // Builds a URL for further requests
    func buildRequestURL(urlString: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: urlString) else {
            throw DebridError.InvalidUrl
        }

        components.queryItems = [
            URLQueryItem(name: "agent", value: appName)
        ] + queryItems

        if let url = components.url {
            return url
        } else {
            throw DebridError.InvalidUrl
        }
    }

    // MARK: - Instant availability

    func instantAvailability(magnets: [Magnet]) async throws {
        let now = Date().timeIntervalSince1970

        let sendMagnets = magnets.filter { magnet in
            if let IAIndex = IAValues.firstIndex(where: { $0.magnet.hash == magnet.hash }) {
                if now > IAValues[IAIndex].expiryTimeStamp {
                    IAValues.remove(at: IAIndex)
                    return true
                } else {
                    return false
                }
            } else {
                return true
            }
        }

        // Fetch the user magnets to the latest version
        try await getUserMagnets()

        for cloudMagnet in cloudMagnets {
            if cachedStatus.contains(cloudMagnet.status),
               sendMagnets.contains(where: { $0.hash == cloudMagnet.hash })
            {
                IAValues.append(
                    DebridIA(
                        magnet: Magnet(hash: cloudMagnet.hash, link: nil),
                        expiryTimeStamp: Date().timeIntervalSince1970 + 300,
                        files: []
                    )
                )
            }
        }
    }

    // MARK: - Downloading

    // Wrapper function to fetch a download link from the API
    func getRestrictedFile(magnet: Magnet, ia: DebridIA?, iaFile: DebridIAFile?) async throws -> (restrictedFile: DebridIAFile?, newIA: DebridIA?) {
        let selectedMagnetId: String

        if let existingMagnet = cloudMagnets.first(where: {
            $0.hash == magnet.hash && cachedStatus.contains($0.status)
        }) {
            selectedMagnetId = existingMagnet.id
        } else {
            let magnetId = try await addMagnet(magnet: magnet)
            selectedMagnetId = String(magnetId)
        }

        let rawResponse = try await fetchMagnetStatus(
            magnetId: selectedMagnetId,
            selectedIndex: iaFile?.id ?? 0
        )
        guard let magnets = rawResponse.magnets[safe: 0] else {
            throw DebridError.EmptyUserMagnets
        }

        // Batches require an unrestrict from the user
        if magnets.links.count > 1, iaFile == nil {
            var copiedIA = ia

            copiedIA?.files = magnets.links.enumerated().compactMap { index, file in
                DebridIAFile(
                    id: index,
                    name: file.filename,
                    streamUrlString: file.link
                )
            }

            return (nil, copiedIA)
        }

        if let cloudMagnetFile = magnets.links[safe: iaFile?.id ?? 0] {
            let restrictedFile = DebridIAFile(
                id: 0,
                name: cloudMagnetFile.filename,
                streamUrlString: cloudMagnetFile.link
            )

            return (restrictedFile, nil)
        } else {
            throw DebridError.EmptyUserMagnets
        }
    }

    // Adds a magnet link to the user's AD account
    func addMagnet(magnet: Magnet) async throws -> Int {
        guard let magnetLink = magnet.link else {
            throw DebridError.FailedRequest(description: "The magnet link is invalid")
        }

        var request = try URLRequest(url: buildRequestURL(urlString: "\(baseApiUrl)/magnet/upload"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "magnets[]", value: magnetLink)
        ]

        guard let bodyData = bodyComponents.percentEncodedQuery?.data(using: .utf8) else {
            throw DebridError.EmptyData
        }

        request.httpBody = bodyData

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(ADResponse<AddMagnetResponse>.self, from: data).data

        if let magnet = rawResponse.magnets[safe: 0] {
            if !magnet.ready {
                throw DebridError.IsCaching
            }

            return magnet.id
        } else {
            throw DebridError.InvalidResponse
        }
    }

    func fetchMagnetStatus(magnetId: String, selectedIndex: Int?) async throws -> MagnetStatusResponse {
        let queryItems = [
            URLQueryItem(name: "id", value: magnetId)
        ]
        var request = try URLRequest(url: buildRequestURL(urlString: "\(baseApiUrl)/magnet/status", queryItems: queryItems))

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(ADResponse<MagnetStatusResponse>.self, from: data).data

        return rawResponse
    }

    // Known as unlockLink in AD's API
    func unrestrictFile(_ restrictedFile: DebridIAFile) async throws -> String {
        let queryItems = [
            URLQueryItem(name: "link", value: restrictedFile.streamUrlString)
        ]
        var request = try URLRequest(url: buildRequestURL(urlString: "\(baseApiUrl)/link/unlock", queryItems: queryItems))

        let data = try await performRequest(request: &request, requestName: "unlockLink")
        let rawResponse = try jsonDecoder.decode(ADResponse<UnlockLinkResponse>.self, from: data).data

        return rawResponse.link
    }

    func saveLink(link: String) async throws {
        let queryItems = [
            URLQueryItem(name: "links[]", value: link)
        ]
        var request = try URLRequest(url: buildRequestURL(urlString: "\(baseApiUrl)/user/links/save", queryItems: queryItems))

        try await performRequest(request: &request, requestName: #function)
    }

    // MARK: - Cloud methods

    func getUserMagnets() async throws {
        var request = try URLRequest(url: buildRequestURL(urlString: "\(baseApiUrl)/magnet/status"))

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(ADResponse<MagnetStatusResponse>.self, from: data).data

        cloudMagnets = rawResponse.magnets.map { magnetResponse in
            DebridCloudMagnet(
                id: String(magnetResponse.id),
                fileName: magnetResponse.filename,
                status: magnetResponse.status,
                hash: magnetResponse.hash,
                links: magnetResponse.links.map(\.link)
            )
        }
    }

    func deleteUserMagnet(cloudMagnetId: String?) async throws {
        guard let cloudMagnetId else {
            throw DebridError.FailedRequest(description: "The cloud magnetID \(String(describing: cloudMagnetId)) is invalid")
        }

        let queryItems = [
            URLQueryItem(name: "id", value: cloudMagnetId)
        ]
        var request = try URLRequest(url: buildRequestURL(urlString: "\(baseApiUrl)/magnet/delete", queryItems: queryItems))

        try await performRequest(request: &request, requestName: #function)
    }

    func getUserDownloads() async throws {
        var request = try URLRequest(url: buildRequestURL(urlString: "\(baseApiUrl)/user/links"))

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(ADResponse<SavedLinksResponse>.self, from: data).data

        // The link is also the ID
        cloudDownloads = rawResponse.links.map { link in
            DebridCloudDownload(
                id: link.link, fileName: link.filename, link: link.link
            )
        }
    }

    // Not used
    func checkUserDownloads(link: String) async throws -> String? {
        link
    }

    // The downloadId is actually the download link
    func deleteUserDownload(downloadId: String) async throws {
        let queryItems = [
            URLQueryItem(name: "link", value: downloadId)
        ]
        var request = try URLRequest(url: buildRequestURL(urlString: "\(baseApiUrl)/user/links/delete", queryItems: queryItems))

        try await performRequest(request: &request, requestName: #function)
    }
}
