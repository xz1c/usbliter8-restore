import XCTest
@testable import Usb8RestoreSwift

final class DFUSerialParserTests: XCTestCase {
    func testParsesPwndfuSerial() {
        let serial = "CPID:8020 CPRV:11 CPFM:03 SCEP:01 BDID:0C ECID:000231A00EE9002E IBFL:3C SRTG:[iBoot-3865.0.0.4.7] PWND:[usbliter8]"

        let info = DFUSerialParser.parse(serial)

        XCTAssertEqual(info.cpid, "0x8020")
        XCTAssertEqual(info.bdid, 0x0C)
        XCTAssertEqual(info.ecid, "000231A00EE9002E")
        XCTAssertNil(info.serialNumber)
        XCTAssertTrue(info.isPwndfu)
    }

    func testParsesRecoverySerial() {
        let serial = "SDOM:01 CPID:8020 CPRV:11 CPFM:03 SCEP:01 BDID:0C ECID:000231A00EE9002E IBFL:3D SRNM:[G0NYV6GBKXKN]"

        let info = DFUSerialParser.parse(serial)

        XCTAssertEqual(info.cpid, "0x8020")
        XCTAssertEqual(info.bdid, 0x0C)
        XCTAssertEqual(info.ecid, "000231A00EE9002E")
        XCTAssertEqual(info.serialNumber, "G0NYV6GBKXKN")
        XCTAssertFalse(info.isPwndfu)
    }
}
