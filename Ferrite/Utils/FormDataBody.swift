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
            tempBody.append("--\(boundary)\r\n".data(using: .utf8) ?? Data())
            tempBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8) ?? Data())
            tempBody.append("\(value)\r\n".data(using: .utf8) ?? Data())
        }

        tempBody.append("--\(boundary)--\r\n".data(using: .utf8) ?? Data())

        self.body = tempBody
    }
}
