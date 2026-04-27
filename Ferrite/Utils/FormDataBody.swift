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
            if let line1 = "--\(boundary)\r\n".data(using: .utf8) {
                tempBody.append(line1)
            }
            if let line2 = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8) {
                tempBody.append(line2)
            }
            if let line3 = "\(value)\r\n".data(using: .utf8) {
                tempBody.append(line3)
            }
        }

        if let line4 = "--\(boundary)--\r\n".data(using: .utf8) {
            tempBody.append(line4)
        }

        self.body = tempBody
    }
}
