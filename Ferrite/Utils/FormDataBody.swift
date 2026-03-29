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

    init(params: [String: String]) {
        var body = Data()

        for (key, value) in params {
            if let boundaryPrefix = "--\(boundary)\r\n".data(using: .utf8),
               let contentDisposition = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8),
               let valueData = "\(value)\r\n".data(using: .utf8)
            {
                body.append(boundaryPrefix)
                body.append(contentDisposition)
                body.append(valueData)
            }
        }

        if let boundarySuffix = "--\(boundary)--\r\n".data(using: .utf8) {
            body.append(boundarySuffix)
        }

        self.body = body
    }
}
