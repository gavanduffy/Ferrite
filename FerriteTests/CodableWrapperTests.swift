//
//  CodableWrapperTests.swift
//  FerriteTests
//

import XCTest
@testable import Ferrite

final class CodableWrapperTests: XCTestCase {
    struct MockValue: Codable, Equatable {
        let id: Int
        let tag: String
    }

    func testCodableWrapperBasic() {
        let value = MockValue(id: 42, tag: "test")
        let wrapper = CodableWrapper(value: value)
        let rawValue = wrapper.rawValue

        guard let decodedWrapper = CodableWrapper<MockValue>(rawValue: rawValue) else {
            XCTFail("Failed to decode CodableWrapper from rawValue")
            return
        }

        XCTAssertEqual(wrapper.value, decodedWrapper.value)
    }

    func testCodableWrapperInvalid() {
        let invalidRawValue = "invalid json"
        let decodedWrapper = CodableWrapper<MockValue>(rawValue: invalidRawValue)

        XCTAssertNil(decodedWrapper)
    }

    func testCodableWrapperEmptyString() {
        let decodedWrapper = CodableWrapper<MockValue>(rawValue: "")
        XCTAssertNil(decodedWrapper)
    }
}
