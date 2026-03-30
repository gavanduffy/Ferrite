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
            if let boundaryData = "--\(boundary)\r\n".data(using: .utf8),
               let dispositionData = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8),
               let valueData = "\(value)\r\n".data(using: .utf8)
            {
                tempBody.append(boundaryData)
                tempBody.append(dispositionData)
                tempBody.append(valueData)
            }
        }

        if let finalBoundaryData = "--\(boundary)--\r\n".data(using: .utf8) {
            tempBody.append(finalBoundaryData)
        }

        self.body = tempBody
    }
}
