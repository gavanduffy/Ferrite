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
        let boundaryString = UUID().uuidString
        var bodyData = Data()

        for (key, value) in params {
            let bodyItems = [
                "--\(boundaryString)\r\n",
                "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n",
                "\(value)\r\n"
            ]

            for item in bodyItems {
                if let data = item.data(using: .utf8) {
                    bodyData.append(data)
                }
            }
        }

        if let footerData = "--\(boundaryString)--\r\n".data(using: .utf8) {
            bodyData.append(footerData)
        }

        self.boundary = boundaryString
        self.body = bodyData
    }
}
