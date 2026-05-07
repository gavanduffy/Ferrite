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
        var bodyString = ""

        for (key, value) in params {
            bodyString += "--\(boundary)\r\n"
            bodyString += "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n"
            bodyString += "\(value)\r\n"
        }

        bodyString += "--\(boundary)--\r\n"

        self.body = bodyString.data(using: .utf8) ?? Data()
    }
}
