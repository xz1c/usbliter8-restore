import XCTest
@testable import Usb8RestoreSwift

final class DeviceSupportCatalogTests: XCTestCase {
    func testLoadsBundledAppleMobileDeviceCatalog() {
        XCTAssertEqual(DeviceSupportCatalog.displayName(productType: "iPhone9,1"), "iPhone 7")
        XCTAssertEqual(DeviceSupportCatalog.displayName(productType: "iPhone18,1"), "iPhone 17 Pro")
        XCTAssertEqual(DeviceSupportCatalog.displayName(productType: "iPad17,4"), "iPad Pro 13-inch (M5)")
    }

    func testAllSupportedDevicesCanBeMatchedFromRecoveryIdentifiers() {
        for device in DeviceSupportCatalog.supportedDevices {
            let cpid = device.cpid.replacingOccurrences(of: "0x", with: "")
            let bdid = String(format: "%02X", device.bdid)
            let recoverySerial = "CPID:\(cpid) BDID:\(bdid) ECID:0000000000000001 SRNM:[TESTSERIAL]"
            let info = DFUSerialParser.parse(recoverySerial)
            let support = DeviceSupportCatalog.support(cpid: info.cpid, bdid: info.bdid)

            XCTAssertEqual(support, device, "Recovery identifiers should match \(device.displayName) \(device.cpid)/\(bdid)")
        }
    }
}
