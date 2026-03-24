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
            if let boundaryStart = "--\(boundary)\r\n".data(using: .utf8),
               let contentDisp = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8),
               let valueData = "\(value)\r\n".data(using: .utf8)
            {
                body.append(boundaryStart)
                body.append(contentDisp)
                body.append(valueData)
            }
        }

        if let boundaryEnd = "--\(boundary)--\r\n".data(using: .utf8) {
            body.append(boundaryEnd)
        }

        self.body = body
    }
}
