//
//  TorBoxWrapper.swift
//  Ferrite
//
//  Created by Brian Dashore on 6/11/24.
//

import Foundation

class TorBox: DebridSource, ObservableObject {
    let id = "TorBox"
    let abbreviation = "TB"
    let website = "https://torbox.app"
    let description: String? = "TorBox is a debrid service that is used for downloads and media playback with seeding. " +
        "Both free and paid plans are available."
    let cachedStatus: [String] = ["cached", "completed"]

    @Published var authProcessing: Bool = false
    var isLoggedIn: Bool {
        getToken() != nil
    }

    var supportsWebLinks: Bool { true }
    var supportsMagnetUnrestrict: Bool { true }
    var supportsTorrentUpload: Bool { true }
    var supportsTransferFileListing: Bool { true }

    var manualToken: String? {
        if UserDefaults.standard.bool(forKey: "TorBox.UseManualKey") {
            return getToken()
        } else {
            return nil
        }
    }

    @Published var IAValues: [DebridIA] = []
    @Published var cloudDownloads: [DebridCloudDownload] = []
    @Published var cloudMagnets: [DebridCloudMagnet] = []
    var cloudTTL: Double = 0.0

    private let baseApiUrl = "https://api.torbox.app/v1/api"
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    init() {
        // Populate user downloads and magnets
        Task {
            try? await getUserMagnets()
        }
    }

    // MARK: - Auth

    func setApiKey(_ key: String) {
        FerriteKeychain.shared.set(key, forKey: "TorBox.ApiKey")
        UserDefaults.standard.set(true, forKey: "TorBox.UseManualKey")
    }

    func logout() async {
        FerriteKeychain.shared.delete("TorBox.ApiKey")
        UserDefaults.standard.removeObject(forKey: "TorBox.UseManualKey")
    }

    private func getToken() -> String? {
        FerriteKeychain.shared.get("TorBox.ApiKey")
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
            throw DebridError.FailedRequest(description: "The request \(requestName) failed because you were unauthorized. Please relogin to TorBox in Settings.")
        } else {
            throw DebridError.FailedRequest(description: "The request \(requestName) failed with status code \(response.statusCode).")
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

        if sendMagnets.isEmpty {
            return
        }

        guard var components = URLComponents(string: "\(baseApiUrl)/torrents/checkcached") else {
            throw DebridError.InvalidUrl
        }
        components.queryItems = sendMagnets.map { URLQueryItem(name: "hash", value: $0.hash) }
        components.queryItems?.append(URLQueryItem(name: "format", value: "list"))
        components.queryItems?.append(URLQueryItem(name: "list_files", value: "true"))

        guard let url = components.url else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TBResponse<InstantAvailabilityData>.self, from: data)

        // If the data is a failure, return
        guard case let .links(iaObjects) = rawResponse.data else {
            return
        }

        let availableHashes = iaObjects.map { iaObject in
            DebridIA(
                magnet: Magnet(hash: iaObject.hash, link: nil),
                expiryTimeStamp: Date().timeIntervalSince1970 + 300,
                files: iaObject.files.enumerated().compactMap { index, iaFile in
                    guard let fileName = iaFile.name.split(separator: "/").last else {
                        return nil
                    }

                    return DebridIAFile(
                        id: index,
                        name: String(fileName)
                    )
                }
            )
        }

        IAValues += availableHashes
    }

    // MARK: - Downloading

    func getRestrictedFile(magnet: Magnet, ia: DebridIA?, iaFile: DebridIAFile?) async throws -> (restrictedFile: DebridIAFile?, newIA: DebridIA?) {
        let cloudMagnetId = try await createTorrent(magnet: magnet)
        let cloudMagnetList = try await myTorrentList()
        guard let filteredCloudMagnet = cloudMagnetList.first(where: { $0.id == cloudMagnetId }) else {
            throw DebridError.FailedRequest(description: "Could not find a cached magnet. Are you sure it's cached?")
        }

        // If the user magnet isn't saved, it's considered as caching
        guard cachedStatus.contains(filteredCloudMagnet.downloadState) else {
            throw DebridError.IsCaching
        }

        guard let cloudMagnetFile = filteredCloudMagnet.files[safe: iaFile?.id ?? 0] else {
            throw DebridError.EmptyUserMagnets
        }

        let restrictedFile = DebridIAFile(id: cloudMagnetFile.id, name: cloudMagnetFile.name, streamUrlString: String(cloudMagnetId))
        return (restrictedFile, nil)
    }

    private func createTorrent(magnet: Magnet) async throws -> Int {
        guard let url = URL(string: "\(baseApiUrl)/torrents/createtorrent") else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        guard let magnetLink = magnet.link else {
            throw DebridError.EmptyData
        }

        let formData = FormDataBody(params: ["magnet": magnetLink])
        request.setValue("multipart/form-data; boundary=\(formData.boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = formData.body

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TBResponse<CreateTorrentResponse>.self, from: data)

        guard let torrentId = rawResponse.data?.torrentId else {
            throw DebridError.EmptyData
        }

        return torrentId
    }

    private func myTorrentList() async throws -> [MyTorrentListResponse] {
        guard let url = URL(string: "\(baseApiUrl)/torrents/mylist") else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TBResponse<[MyTorrentListResponse]>.self, from: data)

        guard let torrentList = rawResponse.data else {
            throw DebridError.EmptyData
        }

        return torrentList
    }

    func unrestrictFile(_ restrictedFile: DebridIAFile) async throws -> String {
        guard var components = URLComponents(string: "\(baseApiUrl)/torrents/requestdl") else {
            throw DebridError.InvalidUrl
        }

        components.queryItems = [
            URLQueryItem(name: "token", value: getToken()),
            URLQueryItem(name: "torrent_id", value: restrictedFile.streamUrlString),
            URLQueryItem(name: "file_id", value: String(restrictedFile.id))
        ]

        guard let url = components.url else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TBResponse<RequestDLResponse>.self, from: data)

        guard let unrestrictedLink = rawResponse.data else {
            throw DebridError.FailedRequest(description: "Could not get an unrestricted URL from TorBox.")
        }

        return unrestrictedLink
    }

    // MARK: - Cloud methods

    // Unused
    func getUserDownloads() async throws {
        let webDownloads = try await myWebDownloadList()
        cloudDownloads = webDownloads.compactMap { item in
            guard let id = item.id else {
                return nil
            }

            return DebridCloudDownload(
                id: String(id),
                fileName: item.name ?? "Web download",
                link: item.link ?? ""
            )
        }
    }

    func checkUserDownloads(link: String) async throws -> String? {
        link
    }

    func deleteUserDownload(downloadId: String) async throws {
        guard let url = URL(string: "\(baseApiUrl)/webdl/controlwebdownload") else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ControlWebDownloadRequest(webdownloadId: downloadId, operation: "Delete")
        request.httpBody = try jsonEncoder.encode(body)

        try await performRequest(request: &request, requestName: #function)
    }

    func getUserMagnets() async throws {
        let cloudMagnetList = try await myTorrentList()
        cloudMagnets = cloudMagnetList.map { cloudMagnet in

            // Only need one link to force a green badge
            DebridCloudMagnet(
                id: String(cloudMagnet.id),
                fileName: cloudMagnet.name,
                status: cloudMagnet.downloadState,
                hash: cloudMagnet.hash,
                links: cloudMagnet.files.map { String($0.id) }
            )
        }
    }

    func deleteUserMagnet(cloudMagnetId: String?) async throws {
        guard let cloudMagnetId else {
            throw DebridError.InvalidPostBody
        }

        guard let url = URL(string: "\(baseApiUrl)/torrents/controltorrent") else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ControlTorrentRequest(torrentId: cloudMagnetId, operation: "Delete")
        request.httpBody = try jsonEncoder.encode(body)

        try await performRequest(request: &request, requestName: "controltorrent")
    }

    // MARK: - Transfer methods (Add tab / Cloud browsing)

    func addWebLink(_ link: String) async throws -> DebridTransferHandle {
        guard URL(string: link) != nil else {
            throw DebridError.InvalidUrl
        }

        let webdownloadId = try await createWebDownload(link: link)
        return DebridTransferHandle(id: String(webdownloadId), kind: .webDownload)
    }

    func addMagnetLink(_ link: String) async throws -> DebridTransferHandle {
        let magnet = Magnet(hash: nil, link: link)
        guard magnet.link != nil else {
            throw DebridError.InvalidUrl
        }

        let torrentId = try await createTorrent(magnet: magnet)
        return DebridTransferHandle(id: String(torrentId), kind: .torrent)
    }

    func uploadTorrentFile(_ fileUrl: URL) async throws -> DebridTransferHandle {
        let torrentId = try await createTorrent(fileUrl: fileUrl)
        return DebridTransferHandle(id: String(torrentId), kind: .torrent)
    }

    func fetchTransferFiles(_ handle: DebridTransferHandle) async throws -> [DebridTransferFile] {
        switch handle.kind {
        case .webDownload:
            let webDownloads = try await myWebDownloadList()
            guard let item = webDownloads.first(where: { String($0.id ?? -1) == handle.id }) else {
                return []
            }

            return [
                DebridTransferFile(
                    id: handle.id,
                    name: item.name ?? "Web download",
                    size: item.size,
                    link: item.link
                )
            ]
        case .torrent:
            let torrentList = try await myTorrentList()
            guard let torrent = torrentList.first(where: { String($0.id) == handle.id }) else {
                return []
            }

            return torrent.files.map { file in
                DebridTransferFile(
                    id: String(file.id),
                    name: file.shortName.isEmpty ? file.name : file.shortName,
                    path: file.name,
                    size: nil
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
            let downloadLink = try await requestWebDownload(webdownloadId: handle.id)
            return DebridUnrestrictResult(
                name: file.name,
                urlString: downloadLink,
                size: file.size,
                mimeType: nil
            )
        case .torrent:
            guard let fileId = Int(file.id) else {
                throw DebridError.InvalidPostBody
            }

            let downloadLink = try await requestTorrentDownload(torrentId: handle.id, fileId: fileId)
            return DebridUnrestrictResult(
                name: file.name,
                urlString: downloadLink,
                size: file.size,
                mimeType: nil
            )
        }
    }

    private func createWebDownload(link: String) async throws -> Int {
        guard let url = URL(string: "\(baseApiUrl)/webdl/createwebdownload") else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let formData = FormDataBody(params: ["link": link])
        request.setValue("multipart/form-data; boundary=\(formData.boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = formData.body

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TBResponse<WebDownloadCreateResponse>.self, from: data)

        guard let webdownloadId = rawResponse.data?.id else {
            throw DebridError.EmptyData
        }

        return webdownloadId
    }

    private func myWebDownloadList() async throws -> [WebDownloadListResponse] {
        guard let url = URL(string: "\(baseApiUrl)/webdl/mylist") else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TBResponse<[WebDownloadListResponse]>.self, from: data)

        return rawResponse.data ?? []
    }

    private func requestWebDownload(webdownloadId: String) async throws -> String {
        guard var components = URLComponents(string: "\(baseApiUrl)/webdl/requestdl") else {
            throw DebridError.InvalidUrl
        }

        components.queryItems = [
            URLQueryItem(name: "token", value: getToken()),
            URLQueryItem(name: "webdl_id", value: webdownloadId)
        ]

        guard let url = components.url else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TBResponse<RequestWebDLResponse>.self, from: data)

        guard let unrestrictedLink = rawResponse.data else {
            throw DebridError.FailedRequest(description: "Could not get a web download URL from TorBox.")
        }

        return unrestrictedLink
    }

    private func requestTorrentDownload(torrentId: String, fileId: Int) async throws -> String {
        guard var components = URLComponents(string: "\(baseApiUrl)/torrents/requestdl") else {
            throw DebridError.InvalidUrl
        }

        components.queryItems = [
            URLQueryItem(name: "token", value: getToken()),
            URLQueryItem(name: "torrent_id", value: torrentId),
            URLQueryItem(name: "file_id", value: String(fileId))
        ]

        guard let url = components.url else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TBResponse<RequestDLResponse>.self, from: data)

        guard let unrestrictedLink = rawResponse.data else {
            throw DebridError.FailedRequest(description: "Could not get an unrestricted URL from TorBox.")
        }

        return unrestrictedLink
    }

    private func createTorrent(fileUrl: URL) async throws -> Int {
        guard let url = URL(string: "\(baseApiUrl)/torrents/createtorrent") else {
            throw DebridError.InvalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (body, boundary) = try buildTorrentUploadBody(fileUrl: fileUrl)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let data = try await performRequest(request: &request, requestName: #function)
        let rawResponse = try jsonDecoder.decode(TBResponse<CreateTorrentResponse>.self, from: data)

        guard let torrentId = rawResponse.data?.torrentId else {
            throw DebridError.EmptyData
        }

        return torrentId
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
            let lineBreakData = "\r\n".data(using: .utf8),
            let boundaryEndData = "--\(boundary)--\r\n".data(using: .utf8)
        else {
            throw DebridError.InvalidPostBody
        }

        body.append(boundaryData)
        body.append(dispositionData)
        body.append(contentTypeData)
        body.append(fileData)
        body.append(lineBreakData)
        body.append(boundaryEndData)

        return (body, boundary)
    }
}
