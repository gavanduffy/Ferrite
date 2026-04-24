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
            if let data = "--\(boundary)\r\n".data(using: .utf8) { tempBody.append(data) }
            if let data = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8) { tempBody.append(data) }
            if let data = "\(value)\r\n".data(using: .utf8) { tempBody.append(data) }
        }

        if let data = "--\(boundary)--\r\n".data(using: .utf8) { tempBody.append(data) }

        self.body = tempBody
    }
}
