import XCTest
@testable import Usb8RestoreSwift

final class BootAssetStoreTests: XCTestCase {
    func testDecryptsEverySupportedBootAsset() throws {
        let store = BootAssetStore()
        let codenames = Set(DeviceSupportCatalog.supportedDevices.map(\.ibecCodename))

        for codename in codenames {
            let asset = try store.decryptedPatchedIBEC(for: codename)
            defer { asset.removeTemporaryFile() }

            let attributes = try FileManager.default.attributesOfItem(atPath: asset.url.path)
            let fileSize = try XCTUnwrap(attributes[.size] as? NSNumber).intValue
            XCTAssertGreaterThan(fileSize, 512_000, "Decrypted \(codename) iBEC is unexpectedly small")
            XCTAssertTrue(asset.url.lastPathComponent.hasPrefix("."))
        }
    }
}
