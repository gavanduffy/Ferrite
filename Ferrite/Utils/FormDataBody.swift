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
        var tempBody = Data()

        for (key, value) in params {
            if let dashBoundaryData = "--\(boundary)\r\n".data(using: .utf8),
               let contentDispositionData = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8),
               let valueData = "\(value)\r\n".data(using: .utf8)
            {
                tempBody.append(dashBoundaryData)
                tempBody.append(contentDispositionData)
                tempBody.append(valueData)
            }
        }

        if let endBoundaryData = "--\(boundary)--\r\n".data(using: .utf8) {
            tempBody.append(endBoundaryData)
        }

        body = tempBody
    }
}
