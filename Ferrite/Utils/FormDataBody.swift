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
            if let boundaryPrefix = "--\(boundary)\r\n".data(using: .utf8) {
                tempBody.append(boundaryPrefix)
            }
            if let disposition = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8) {
                tempBody.append(disposition)
            }
            if let valueData = "\(value)\r\n".data(using: .utf8) {
                tempBody.append(valueData)
            }
        }

        if let boundarySuffix = "--\(boundary)--\r\n".data(using: .utf8) {
            tempBody.append(boundarySuffix)
        }

        self.body = tempBody
    }
}
