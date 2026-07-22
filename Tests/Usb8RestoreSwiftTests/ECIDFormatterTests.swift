import XCTest
@testable import Usb8RestoreSwift

final class ECIDFormatterTests: XCTestCase {
    func testConvertsDecimalUniqueChipIDToHexECID() {
        XCTAssertEqual(ECIDFormatter.displayString(from: "7443595721179174"), "001A71E92ED00026")
    }

    func testPadsAndUppercasesHexECID() {
        XCTAssertEqual(ECIDFormatter.displayString(from: "1a71e92ed00026"), "001A71E92ED00026")
    }
}
