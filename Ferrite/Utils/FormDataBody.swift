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
            if let boundaryData = "--\(boundary)\r\n".data(using: .utf8) {
                body.append(boundaryData)
            }
            if let dispositionData = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8) {
                body.append(dispositionData)
            }
            if let valueData = "\(value)\r\n".data(using: .utf8) {
                body.append(valueData)
            }
        }

        if let finalBoundaryData = "--\(boundary)--\r\n".data(using: .utf8) {
            body.append(finalBoundaryData)
        }

        self.body = body
    }
}
