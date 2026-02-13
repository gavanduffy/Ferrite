//
//  SetTests.swift
//  FerriteTests
//

import XCTest
@testable import Ferrite

final class SetTests: XCTestCase {
    struct MockElement: Codable, Hashable {
        let id: Int
        let name: String
    }

    func testSetRawRepresentableInt() {
        let set: Set<Int> = [1, 2, 3]
        let rawValue = set.rawValue

        guard let decodedSet = Set<Int>(rawValue: rawValue) else {
            XCTFail("Failed to decode set from rawValue")
            return
        }

        XCTAssertEqual(set, decodedSet)
    }

    func testSetRawRepresentableString() {
        let set: Set<String> = ["a", "b", "c"]
        let rawValue = set.rawValue

        guard let decodedSet = Set<String>(rawValue: rawValue) else {
            XCTFail("Failed to decode set from rawValue")
            return
        }

        XCTAssertEqual(set, decodedSet)
    }

    func testSetRawRepresentableEmpty() {
        let set: Set<Int> = []
        let rawValue = set.rawValue

        guard let decodedSet = Set<Int>(rawValue: rawValue) else {
            XCTFail("Failed to decode set from rawValue")
            return
        }

        XCTAssertEqual(set, decodedSet)
        XCTAssertTrue(decodedSet.isEmpty)
    }

    func testSetRawRepresentableCustomStruct() {
        let set: Set<MockElement> = [
            MockElement(id: 1, name: "one"),
            MockElement(id: 2, name: "two")
        ]
        let rawValue = set.rawValue

        guard let decodedSet = Set<MockElement>(rawValue: rawValue) else {
            XCTFail("Failed to decode set from rawValue")
            return
        }

        XCTAssertEqual(set, decodedSet)
    }

    func testSetRawRepresentableInvalid() {
        let invalidRawValue = "invalid json"
        let decodedSet = Set<Int>(rawValue: invalidRawValue)

        XCTAssertNil(decodedSet)
    }
}
