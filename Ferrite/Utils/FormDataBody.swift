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
            if let boundaryData = "--\(boundary)\r\n".data(using: .utf8) {
                tempBody.append(boundaryData)
            }
            if let dispositionData = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8) {
                tempBody.append(dispositionData)
            }
            if let valueData = "\(value)\r\n".data(using: .utf8) {
                tempBody.append(valueData)
            }
        }

        if let endBoundaryData = "--\(boundary)--\r\n".data(using: .utf8) {
            tempBody.append(endBoundaryData)
        }

        self.body = tempBody
    }
}
