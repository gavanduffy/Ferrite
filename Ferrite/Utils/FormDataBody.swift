//
//  FormDataBody.swift
//  Ferrite
//
//  Created by Brian Dashore on 6/12/24.
//

import Foundation

struct FormDataBody {
    let boundary: String = UUID().uuidString
    let body: Data

    init(parameters: [String: String], fileData: Data? = nil, fileName: String? = nil, fileKey: String? = nil) throws {
        var body = Data()

        for (key, value) in parameters {
            guard let boundaryData = "--\(boundary)\r\n".data(using: .utf8),
                  let contentDispositionData = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8),
                  let valueData = "\(value)\r\n".data(using: .utf8) else {
                throw FormDataError.encodingFailed
            }
            body.append(boundaryData)
            body.append(contentDispositionData)
            body.append(valueData)
        }

        if let fileData, let fileName, let fileKey {
            guard let boundaryData = "--\(boundary)\r\n".data(using: .utf8),
                  let contentDispositionData = "Content-Disposition: form-data; name=\"\(fileKey)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8),
                  let contentTypeData = "Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8),
                  let lineBreakData = "\r\n".data(using: .utf8) else {
                throw FormDataError.encodingFailed
            }
            body.append(boundaryData)
            body.append(contentDispositionData)
            body.append(contentTypeData)
            body.append(fileData)
            body.append(lineBreakData)
        }

        guard let endBoundaryData = "--\(boundary)--\r\n".data(using: .utf8) else {
            throw FormDataError.encodingFailed
        }
        body.append(endBoundaryData)

        self.body = body
    }
}

enum FormDataError: Error {
    case encodingFailed
}
