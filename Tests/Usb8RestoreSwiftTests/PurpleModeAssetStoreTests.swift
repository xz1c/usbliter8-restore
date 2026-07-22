import XCTest
@testable import Usb8RestoreSwift

final class PurpleModeAssetStoreTests: XCTestCase {
    func testDecryptsEverySupportedPurpleModeAsset() throws {
        let store = PurpleModeAssetStore()

        for support in PurpleModeSupportCatalog.supportedDevices {
            let assets = try store.decryptedAssets(for: support)
            defer { assets.removeTemporaryFiles() }

            let ibssSize = try fileSize(at: assets.ibssURL)
            let diagSize = try fileSize(at: assets.diagURL)

            XCTAssertGreaterThan(ibssSize, 1_000_000, "\(support.board) iBSS is unexpectedly small")
            XCTAssertGreaterThan(diagSize, 1_000_000, "\(support.board) diag is unexpectedly small")
            XCTAssertTrue(assets.ibssURL.lastPathComponent.hasPrefix("."))
            XCTAssertTrue(assets.diagURL.lastPathComponent.hasPrefix("."))
        }
    }

    func testPurpleModeSupportMatchesRecoveryIdentifiers() {
        for support in PurpleModeSupportCatalog.supportedDevices {
            let cpid = support.cpid.replacingOccurrences(of: "0x", with: "")
            let bdid = String(format: "%02X", support.bdid)
            let recoverySerial = "CPID:\(cpid) BDID:\(bdid) ECID:0000000000000001 PWND:[usbliter8]"
            let info = DFUSerialParser.parse(recoverySerial)

            XCTAssertEqual(PurpleModeSupportCatalog.support(cpid: info.cpid, bdid: info.bdid), support)
        }
    }

    private func fileSize(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.size] as? NSNumber).intValue
    }
}
