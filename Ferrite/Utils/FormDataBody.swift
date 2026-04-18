//
//  FormDataBody.swift
//  Ferrite
//
//  Created by Brian Dashore on 6/12/24.
//

import Foundation

struct FormDataBody {
    let boundary: String
    let body: Data

    init(params: [String: String]) {
        let boundary = UUID().uuidString
        var tempBody = Data()

        for (key, value) in params {
            if let boundaryData = "--\(boundary)\r\n".data(using: .utf8),
               let contentDispositionData = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8),
               let valueData = "\(value)\r\n".data(using: .utf8)
            {
                tempBody.append(boundaryData)
                tempBody.append(contentDispositionData)
                tempBody.append(valueData)
            }
        }

        if let endBoundaryData = "--\(boundary)--\r\n".data(using: .utf8) {
            tempBody.append(endBoundaryData)
        }

        self.boundary = boundary
        self.body = tempBody
    }
}
