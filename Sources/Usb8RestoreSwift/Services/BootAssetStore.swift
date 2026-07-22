import CryptoKit
import Foundation

struct BootAssetStore: Sendable {
    private let assetKeySeed = "usb8-restore.boot-assets.v1.local-bundle"

    func decryptedPatchedIBEC(for codename: String) throws -> DecryptedBootAsset {
        let encryptedURL = try encryptedAssetURL(for: codename)
        let encryptedData = try Data(contentsOf: encryptedURL)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let keyDigest = SHA256.hash(data: Data(assetKeySeed.utf8))
        let key = SymmetricKey(data: Data(keyDigest))
        let plaintext = try AES.GCM.open(sealedBox, using: key)

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(".usb8-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: temporaryDirectory.path)

        let outputURL = temporaryDirectory
            .appendingPathComponent(".\(UUID().uuidString)")
        try plaintext.write(to: outputURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: outputURL.path)
        return DecryptedBootAsset(url: outputURL, temporaryDirectory: temporaryDirectory)
    }

    private func encryptedAssetURL(for codename: String) throws -> URL {
        guard let url = AppResourceLocator.resourceURL(
            name: "\(codename).ibec",
            extension: "enc",
            subdirectories: ["BootAssets", "Resources/BootAssets"]
        ) else {
            throw RestoreError.missingBootAsset
        }
        return url
    }
}

struct DecryptedBootAsset: Sendable {
    let url: URL
    let temporaryDirectory: URL

    func removeTemporaryFile() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}

extension Bundle {
    static var usb8Resources: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}
