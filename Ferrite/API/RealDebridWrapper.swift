//
//  RealDebridWrapper.swift
//  Ferrite
//
//  Created by Brian Dashore on 7/7/22.
//

import Foundation

class RealDebrid: PollingDebridSource, ObservableObject {
    let id = "RealDebrid"
    let abbreviation = "RD"
    let website = "https://real-debrid.com"
    let description: String? = "RealDebrid is a debrid service that is used for downloads and media playback. " +
        "You must pay to access this service. \n\n" +
        "It is not recommended to use this service since media cache checks are not possible via the API. " +
        "Ferrite's instant availability solely looks at a user's magnet library. \n\n" +
        "If you must use this service, it is recommended to download search results manually using the context menu. \n\n" +
        "This service does not inform if a magnet link is a batch before downloading."

    let cachedStatus: [String] = ["downloaded"]
    var authTask: Task<Void, Error>?

    @Published var authProcessing: Bool = false

    var supportsWebLinks: Bool { true }
    var supportsMagnetUnrestrict: Bool { true }
    var supportsTorrentUpload: Bool { true }
    var supportsTransferFileListing: Bool { true }

    // Check the manual token since getTokens() is async
    var isLoggedIn: Bool {
        FerriteKeychain.shared.get("RealDebrid.AccessToken") != nil
    }

    var manualToken: String? {
        if UserDefaults.standard.bool(forKey: "RealDebrid.UseManualKey") {
            return FerriteKeychain.shared.get("RealDebrid.AccessToken")
        } else {
            return nil
        }
    }

    @Published var IAValues: [DebridIA] = []
    @Published var cloudDownloads: [DebridCloudDownload] = []
    @Published var cloudMagnets: [DebridCloudMagnet] = []
    var cloudTTL: Double = 0.0

    private let baseAuthUrl = "https://api.real-debrid.com/oauth/v2"
    private let baseApiUrl = "https://api.real-debrid.com/rest/1.0"
    private let openSourceClientId = "X245A4XAIBGVM"

    private let jsonDecoder = JSONDecoder()

    @MainActor
    private func setUserDefaultsValue(_ value: Any, forKey: String) {
        UserDefaults.standard.set(value, forKey: forKey)
    }

    @MainActor
    private func removeUserDefaultsValue(forKey: String) {
        UserDefaults.standard.removeObject(forKey: forKey)
    }

    init() {
        // Populate user downloads and magnets
        Task {
            try? await getUserDownloads()
            try? await getUserMagnets()
        }
    }

    // MARK: - Auth

    // Fetches the device code from RD
    func getAuthUrl() async throws -> URL {
        guard var urlComponents = URLComponents(string: "\(baseAuthUrl)/device/code") else {
            throw DebridError.InvalidUrl
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: openSourceClientId),
            URLQueryItem(name: "new_credentials", value: "yes")
        ]

        guard let url = urlComponents.url else {
            throw DebridError.InvalidUrl
        }

        let request = URLRequest(url: url)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            // Validate the URL before doing anything else
            let rawResponse = try jsonDecoder.decode(DeviceCodeResponse.self, from: data)
            guard let directVerificationUrl = URL(string: rawResponse.directVerificationURL) else {
                throw DebridError.AuthQuery(description: "The verification URL is invalid")
            }

            // Spawn the polling task separately
            authTask = Task {
                try await getDeviceCredentials(deviceCode: rawResponse.deviceCode)
            }

            return directVerificationUrl
        } catch {
            print("Couldn't get the new client creds!")
            throw DebridError.AuthQuery(description: error.localizedDescription)
        }
    }

    // Fetches the user's client ID and secret
    func getDeviceCredentials(deviceCode: String) async throws {
        guard var urlComponents = URLComponents(string: "\(baseAuthUrl)/device/credentials") else {
            throw DebridError.InvalidUrl
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: openSourceClientId),
            URLQueryItem(name: "code", value: deviceCode)
        ]

        guard let url = urlComponents.url else {
            throw DebridError.InvalidUrl
        }

        let request = URLRequest(url: url)

        // Timer to poll RD API for credentials
        var count = 0

        while count < 12 {
            if Task.isCancelled {
                throw DebridError.AuthQuery(description: "Token request cancelled.")
            }

            let (data, _) = try await URLSession.shared.data(for: request)

            // We don't care if this fails
            let rawResponse = try? jsonDecoder.decode(DeviceCredentialsResponse.self, from: data)

            // If there's a client ID from the response, end the task successfully
            if let clientId = rawResponse?.clientID, let clientSecret = rawResponse?.clientSecret {
                await setUserDefaultsValue(clientId, forKey: "RealDebrid.ClientId")
                FerriteKeychain.shared.set(clientSecret, forKey: "RealDebrid.ClientSecret")

                try await getApiTokens(deviceCode: deviceCode)

                return
            } else {
                try await Task.sleep(seconds: 5)
                count += 1
            }
        }

        throw DebridError.AuthQuery(description: "Could not fetch the client ID and secret in time. Try logging in again.")
    }

    // Fetch all tokens for the user and store in FerriteKeychain.shared
    func getApiTokens(deviceCode: String) async throws {
        guard let clientId = UserDefaults.standard.string(forKey: "RealDebrid.ClientId") else {
            throw DebridError.EmptyData
        }

        guard let clientSecret = FerriteKeychain.shared.get("RealDebrid.ClientSecret") else {
            throw DebridError.EmptyData
        }

        guard let url = URL(string: "\(baseAuthUrl)/token") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "code", value: deviceCode),
            URLQueryItem(name: "grant_type", value: "http://oauth.net/grant_type/device/1.0")
        ]

        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)

        let rawResponse = try jsonDecoder.decode(TokenResponse.self, from: data)

        FerriteKeychain.shared.set(rawResponse.accessToken, forKey: "RealDebrid.AccessToken")
        FerriteKeychain.shared.set(rawResponse.refreshToken, forKey: "RealDebrid.RefreshToken")

        let accessTimestamp = Date().timeIntervalSince1970 + Double(rawResponse.expiresIn)
        await setUserDefaultsValue(accessTimestamp, forKey: "RealDebrid.AccessTokenStamp")
    }

    func getToken() async -> String? {
        let accessTokenStamp = UserDefaults.standard.double(forKey: "RealDebrid.AccessTokenStamp")

        if Date().timeIntervalSince1970 > accessTokenStamp {
            do {
                if let refreshToken = FerriteKeychain.shared.get("RealDebrid.RefreshToken") {
                    try await getApiTokens(deviceCode: refreshToken)
                }
            } catch {
                print(error)
                return nil
            }
        }

        return FerriteKeychain.shared.get("RealDebrid.AccessToken")
    }

    // Adds a manual API key instead of web auth
    // Clear out existing refresh tokens and timestamps
    func setApiKey(_ key: String) {
        FerriteKeychain.shared.set(key, forKey: "RealDebrid.AccessToken")
        FerriteKeychain.shared.delete("RealDebrid.RefreshToken")
        FerriteKeychain.shared.delete("RealDebrid.AccessTokenStamp")

        UserDefaults.standard.set(true, forKey: "RealDebrid.UseManualKey")
    }

    // Deletes tokens from device and RD's servers
    func logout() async {
        FerriteKeychain.shared.delete("RealDebrid.RefreshToken")
        FerriteKeychain.shared.delete("RealDebrid.ClientSecret")
        await removeUserDefaultsValue(forKey: "RealDebrid.ClientId")
        await removeUserDefaultsValue(forKey: "RealDebrid.AccessTokenStamp")

        // Run the request, doesn't matter if it fails
        if let token = FerriteKeychain.shared.get("RealDebrid.AccessToken") {
            if let url = URL(string: "\(baseApiUrl)/disable_access_token") {
                var request = URLRequest(url: url)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }

            FerriteKeychain.shared.delete("RealDebrid.AccessToken")
            await removeUserDefaultsValue(forKey: "RealDebrid.UseManualKey")
        }
    }

    // MARK: - Common request

    // Wrapper request function which matches the responses and returns data
    @discardableResult private func performRequest(request: inout URLRequest, requestName: String) async throws -> Data {
        guard let token = await getToken() else {
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
            throw DebridError.FailedRequest(description: "The request \(requestName) failed because you were unauthorized. Please relogin to RealDebrid in Settings.")
        } else {
            throw DebridError.FailedRequest(description: "The request \(requestName) failed with status code \(response.statusCode).")
        }
    }

    // MARK: - Instant availability

    // Post-API changes
    // Use user magnets to check for IA instead
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
        var selectedMagnetId = ""

        do {
            // Don't queue a new job if the magnet already exists in the user's library
            if let existingCloudMagnet = cloudMagnets.first(where: {
                $0.hash == magnet.hash && cachedStatus.contains($0.status)
            }) {
                selectedMagnetId = existingCloudMagnet.id
            } else {
                selectedMagnetId = try await addMagnet(magnet: magnet)

                try await selectFiles(debridID: selectedMagnetId, fileIds: iaFile?.batchIds ?? [])
            }

            let response = try await torrentInfo(debridID: selectedMagnetId)
            let filteredFiles = response.files.filter { $0.selected == 1 }

            // Need to return this to the user
            if filteredFiles.count > 1, iaFile == nil {
                var copiedIA = ia

                copiedIA?.files = response.files.enumerated().compactMap { index, file in
                    DebridIAFile(
                        id: index,
                        name: file.path,
                        streamUrlString: response.links[safe: index]
                    )
                }

                return (nil, copiedIA)
            }

            // RealDebrid has 1 as the first ID for a file
            let selectedFileId = iaFile?.id ?? 1
            let linkIndex = filteredFiles.firstIndex(where: { $0.id == selectedFileId })

            guard let cloudMagnetLink = response.links[safe: linkIndex ?? -1] else {
                throw DebridError.EmptyUserMagnets
            }

            let restrictedFile = DebridIAFile(id: 0, name: response.filename, streamUrlString: cloudMagnetLink)
            return (restrictedFile, nil)
        } catch {
            if case DebridError.EmptyUserMagnets = error, !selectedMagnetId.isEmpty {
                try? await deleteUserMagnet(cloudMagnetId: selectedMagnetId)
            }

            // Re-raise the error to the calling function
            throw error
        }
    }

    // Adds a magnet link to the user's RD account
    func addMagnet(magnet: Magnet) async throws -> String {
        guard let magnetLink = magnet.link else {
            throw DebridError.FailedRequest(description: "The magnet link is invalid")
        }

        guard let url = URL(string: "\(baseApiUrl)/torrents/addMagnet") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [URLQueryItem(name: "magnet", value: magnetLink)]

        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(AddMagnetResponse.self, from: data)

        return rawResponse.id
    }

    // Queues the magnet link for downloading
    func selectFiles(debridID: String, fileIds: [Int]) async throws {
        guard let url = URL(string: "\(baseApiUrl)/torrents/selectFiles/\(debridID)") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()

        if fileIds.isEmpty {
            bodyComponents.queryItems = [URLQueryItem(name: "files", value: "all")]
        } else {
            let joinedIds = fileIds.map(String.init).joined(separator: ",")
            bodyComponents.queryItems = [URLQueryItem(name: "files", value: joinedIds)]
        }

        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        try await performRequest(request: &request, requestName: #function)
    }

    // Gets the info of a torrent from a given ID
    func torrentInfo(debridID: String) async throws -> TorrentInfoResponse {
        guard let url = URL(string: "\(baseApiUrl)/torrents/info/\(debridID)") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TorrentInfoResponse.self, from: data)

        // Let the user know if a magnet is downloading
        switch rawResponse.status {
        case "downloaded":
            return rawResponse
        case "downloading", "queued":
            throw DebridError.IsCaching
        default:
            throw DebridError.EmptyUserMagnets
        }
    }

    // Downloads link from selectFiles for playback
    func unrestrictFile(_ restrictedFile: DebridIAFile) async throws -> String {
        guard let url = URL(string: "\(baseApiUrl)/unrestrict/link") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [URLQueryItem(name: "link", value: restrictedFile.streamUrlString)]

        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(UnrestrictLinkResponse.self, from: data)

        return rawResponse.download
    }

    // MARK: - Cloud methods

    // Gets the user's cloud magnet library
    func getUserMagnets() async throws {
        guard let url = URL(string: "\(baseApiUrl)/torrents") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode([UserTorrentsResponse].self, from: data)
        cloudMagnets = rawResponse.map { response in
            DebridCloudMagnet(
                id: response.id,
                fileName: response.filename,
                status: response.status,
                hash: response.hash,
                links: [response.id]
            )
        }
    }

    // Deletes a magnet download from RD
    func deleteUserMagnet(cloudMagnetId: String?) async throws {
        let deleteId: String

        if let cloudMagnetId {
            deleteId = cloudMagnetId
        } else {
            // Refresh the user magnet list
            // The first file is the currently caching one
            let _ = try await getUserMagnets()
            guard let firstCloudMagnet = cloudMagnets[safe: -1] else {
                throw DebridError.EmptyUserMagnets
            }

            deleteId = firstCloudMagnet.id
        }

        guard let url = URL(string: "\(baseApiUrl)/torrents/delete/\(deleteId)") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        try await performRequest(request: &request, requestName: #function)
    }

    // Gets the user's downloads
    func getUserDownloads() async throws {
        guard let url = URL(string: "\(baseApiUrl)/downloads") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode([UserDownloadsResponse].self, from: data)
        cloudDownloads = rawResponse.map { response in
            DebridCloudDownload(id: response.id, fileName: response.filename, link: response.download)
        }
    }

    // Not used
    func checkUserDownloads(link: String) async throws -> String? {
        link
    }

    func deleteUserDownload(downloadId: String) async throws {
        guard let url = URL(string: "\(baseApiUrl)/downloads/delete/\(downloadId)") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        try await performRequest(request: &request, requestName: #function)
    }

    // MARK: - Transfer methods (Add tab / Cloud browsing)

    func addWebLink(_ link: String) async throws -> DebridTransferHandle {
        guard URL(string: link) != nil else {
            throw DebridError.InvalidUrl
        }

        return DebridTransferHandle(id: link, kind: .webDownload)
    }

    func addMagnetLink(_ link: String) async throws -> DebridTransferHandle {
        let magnet = Magnet(hash: nil, link: link)
        guard magnet.link != nil else {
            throw DebridError.InvalidUrl
        }

        let torrentId = try await addMagnet(magnet: magnet)
        return DebridTransferHandle(id: torrentId, kind: .torrent)
    }

    func uploadTorrentFile(_ fileUrl: URL) async throws -> DebridTransferHandle {
        let torrentId = try await addTorrent(fileUrl: fileUrl)
        return DebridTransferHandle(id: torrentId, kind: .torrent)
    }

    func fetchTransferFiles(_ handle: DebridTransferHandle) async throws -> [DebridTransferFile] {
        switch handle.kind {
        case .webDownload:
            let response = try await unrestrictWebLink(link: handle.id)
            return [
                DebridTransferFile(
                    id: response.id,
                    name: response.filename,
                    size: response.filesize,
                    link: response.download
                )
            ]
        case .torrent:
            let response = try await torrentInfoAllowCaching(debridID: handle.id)
            return response.files.map { file in
                DebridTransferFile(
                    id: String(file.id),
                    name: file.path,
                    path: file.path,
                    size: file.bytes
                )
            }
        }
    }

    func unrestrictTransferFile(
        _ handle: DebridTransferHandle,
        file: DebridTransferFile
    ) async throws -> DebridUnrestrictResult {
        switch handle.kind {
        case .webDownload:
            if let link = file.link {
                return DebridUnrestrictResult(
                    name: file.name,
                    urlString: link,
                    size: file.size,
                    mimeType: nil
                )
            }

            let response = try await unrestrictWebLink(link: handle.id)
            return DebridUnrestrictResult(
                name: response.filename,
                urlString: response.download,
                size: response.filesize,
                mimeType: response.mimeType
            )
        case .torrent:
            guard let fileId = Int(file.id) else {
                throw DebridError.InvalidPostBody
            }

            try await selectFiles(debridID: handle.id, fileIds: [fileId])
            let response = try await torrentInfo(debridID: handle.id)
            let linkIndex = response.files.firstIndex { $0.id == fileId }
            guard let restrictedLink = response.links[safe: linkIndex ?? -1] else {
                throw DebridError.EmptyUserMagnets
            }

            let restrictedFile = DebridIAFile(
                id: 0,
                name: response.filename,
                streamUrlString: restrictedLink
            )
            let downloadLink = try await unrestrictFile(restrictedFile)
            return DebridUnrestrictResult(
                name: file.name,
                urlString: downloadLink,
                size: file.size,
                mimeType: nil
            )
        }
    }

    private func unrestrictWebLink(link: String) async throws -> UnrestrictLinkResponse {
        guard let url = URL(string: "\(baseApiUrl)/unrestrict/link") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [URLQueryItem(name: "link", value: link)]
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let data = try await performRequest(request: &request, requestName: #function)
        return try jsonDecoder.decode(UnrestrictLinkResponse.self, from: data)
    }

    /// Public helper: obtain a streamable/transcoded link from Real-Debrid for a given web-hosted media URL.
    /// This method re-uses the existing `unrestrictWebLink` endpoint and returns the provider `download` URL.
    /// If the provider marks the resource as streamable, the returned URL is commonly suitable for streaming (HLS / progressive) depending on the provider.
    /// Note: the exact semantics depend on the provider response; callers should validate returned MIME/type or use the URL in a player that supports the stream type.
    func getStreamableLink(for link: String) async throws -> String {
        let response = try await unrestrictWebLink(link: link)

        // The `UnrestrictLinkResponse` contains `download` (direct link) and a `streamable` flag.
        // Return the `download` entry — it is typically the best candidate for streaming playback when `streamable == 1`.
        return response.download
    }

    private func addTorrent(fileUrl: URL) async throws -> String {
        var request = URLRequest(url: try await addTorrentUrl())
        request.httpMethod = "PUT"

        let (body, boundary) = try buildTorrentUploadBody(fileUrl: fileUrl)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(AddMagnetResponse.self, from: data)
        return rawResponse.id
    }

    private func addTorrentUrl() async throws -> URL {
        guard var urlComponents = URLComponents(string: "\(baseApiUrl)/torrents/addTorrent") else {
            throw DebridError.InvalidUrl
        }
        if let host = try await availableHost() {
            urlComponents.queryItems = [URLQueryItem(name: "host", value: host)]
        }

        guard let url = urlComponents.url else {
            throw DebridError.InvalidUrl
        }

        return url
    }

    private func availableHost() async throws -> String? {
        guard let url = URL(string: "\(baseApiUrl)/torrents/availableHosts") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)
        let data = try await performRequest(request: &request, requestName: #function)
        let hosts = try jsonDecoder.decode([AvailableHostResponse].self, from: data)
        return hosts.first?.host
    }

    private func buildTorrentUploadBody(fileUrl: URL) throws -> (Data, String) {
        let boundary = UUID().uuidString
        let fileName = fileUrl.lastPathComponent
        let fileData = try Data(contentsOf: fileUrl)

        var body = Data()
        guard
            let boundaryData = "--\(boundary)\r\n".data(using: .utf8),
            let dispositionData = "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8),
            let contentTypeData = "Content-Type: application/x-bittorrent\r\n\r\n".data(using: .utf8),
            let newlineData = "\r\n".data(using: .utf8),
            let endBoundaryData = "--\(boundary)--\r\n".data(using: .utf8)
        else {
            throw DebridError.InvalidPostBody
        }

        body.append(boundaryData)
        body.append(dispositionData)
        body.append(contentTypeData)
        body.append(fileData)
        body.append(newlineData)
        body.append(endBoundaryData)

        return (body, boundary)
    }

    internal func torrentInfoAllowCaching(debridID: String) async throws -> TorrentInfoResponse {
        guard let url = URL(string: "\(baseApiUrl)/torrents/info/\(debridID)") else {
            throw DebridError.InvalidUrl
        }
        var request = URLRequest(url: url)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TorrentInfoResponse.self, from: data)
        return rawResponse
    }
}
