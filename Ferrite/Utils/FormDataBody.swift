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
        self.boundary = boundary
        var tempBody = Data()

        for (key, value) in params {
            if let boundaryData = "--\(boundary)\r\n".data(using: .utf8),
               let dispositionData = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8),
               let valueData = "\(value)\r\n".data(using: .utf8)
            {
                tempBody.append(boundaryData)
                tempBody.append(dispositionData)
                tempBody.append(valueData)
            }
        }

        if let endBoundaryData = "--\(boundary)--\r\n".data(using: .utf8) {
            tempBody.append(endBoundaryData)
        }

        self.body = tempBody
    }
}
