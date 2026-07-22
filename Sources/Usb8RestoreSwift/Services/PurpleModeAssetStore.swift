import CryptoKit
import Foundation

struct PurpleModeAssetStore: Sendable {
    private let assetKeySeed = "usb8-restore.diag-assets.v1.local-bundle"

    func decryptedAssets(for support: PurpleModeSupport) throws -> DecryptedPurpleModeAssets {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(".usb8-purple-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: temporaryDirectory.path)

        do {
            let ibssURL = try decryptAsset(
                named: "ibss.raw",
                support: support,
                temporaryDirectory: temporaryDirectory
            )
            let diagURL = try decryptAsset(
                named: "diag.img4",
                support: support,
                temporaryDirectory: temporaryDirectory
            )
            return DecryptedPurpleModeAssets(
                ibssURL: ibssURL,
                diagURL: diagURL,
                temporaryDirectory: temporaryDirectory
            )
        } catch {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw error
        }
    }

    private func decryptAsset(named name: String, support: PurpleModeSupport, temporaryDirectory: URL) throws -> URL {
        let encryptedURL = try encryptedAssetURL(named: name, support: support)
        let encryptedData = try Data(contentsOf: encryptedURL)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let keyDigest = SHA256.hash(data: Data(assetKeySeed.utf8))
        let key = SymmetricKey(data: Data(keyDigest))
        let plaintext = try AES.GCM.open(sealedBox, using: key)

        let outputURL = temporaryDirectory.appendingPathComponent(".\(UUID().uuidString)")
        try plaintext.write(to: outputURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: outputURL.path)
        return outputURL
    }

    private func encryptedAssetURL(named name: String, support: PurpleModeSupport) throws -> URL {
        guard let url = AppResourceLocator.resourceURL(
            name: name,
            extension: "enc",
            subdirectories: [
                "DiagAssets/\(support.soc)/\(support.board)",
                "Resources/DiagAssets/\(support.soc)/\(support.board)"
            ]
        ) else {
            throw PurpleModeError.missingDiagAsset
        }
        return url
    }
}

struct DecryptedPurpleModeAssets: Sendable {
    let ibssURL: URL
    let diagURL: URL
    let temporaryDirectory: URL

    func removeTemporaryFiles() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}

struct PurpleModeSupport: Equatable, Sendable {
    let cpid: String
    let bdid: Int
    let displayName: String
    let soc: String
    let board: String
}

enum PurpleModeSupportCatalog {
    static let supportedDevices: [PurpleModeSupport] = [
        PurpleModeSupport(cpid: "0x8020", bdid: 0x0A, displayName: "iPhone XS Max", soc: "t8020", board: "D331AP"),
        PurpleModeSupport(cpid: "0x8020", bdid: 0x0C, displayName: "iPhone XR", soc: "t8020", board: "N841AP"),
        PurpleModeSupport(cpid: "0x8020", bdid: 0x0E, displayName: "iPhone XS", soc: "t8020", board: "D321AP"),
        PurpleModeSupport(cpid: "0x8020", bdid: 0x1A, displayName: "iPhone XS Max", soc: "t8020", board: "D331PAP"),
        PurpleModeSupport(cpid: "0x8020", bdid: 0x14, displayName: "iPad mini 5", soc: "t8020", board: "J210AP"),
        PurpleModeSupport(cpid: "0x8020", bdid: 0x16, displayName: "iPad mini 5", soc: "t8020", board: "J211AP"),
        PurpleModeSupport(cpid: "0x8020", bdid: 0x1C, displayName: "iPad Air 3", soc: "t8020", board: "J217AP"),
        PurpleModeSupport(cpid: "0x8020", bdid: 0x1E, displayName: "iPad Air 3", soc: "t8020", board: "J218AP"),
        PurpleModeSupport(cpid: "0x8020", bdid: 0x24, displayName: "iPad 8", soc: "t8020", board: "J171AP"),
        PurpleModeSupport(cpid: "0x8020", bdid: 0x26, displayName: "iPad 8", soc: "t8020", board: "J172AP"),
        PurpleModeSupport(cpid: "0x8030", bdid: 0x02, displayName: "iPhone 11 Pro Max", soc: "t8030", board: "D431AP"),
        PurpleModeSupport(cpid: "0x8030", bdid: 0x04, displayName: "iPhone 11", soc: "t8030", board: "N104AP"),
        PurpleModeSupport(cpid: "0x8030", bdid: 0x06, displayName: "iPhone 11 Pro", soc: "t8030", board: "D421AP"),
        PurpleModeSupport(cpid: "0x8030", bdid: 0x10, displayName: "iPhone SE 2", soc: "t8030", board: "D79AP"),
        PurpleModeSupport(cpid: "0x8030", bdid: 0x24, displayName: "iPad 9", soc: "t8030", board: "J181AP"),
        PurpleModeSupport(cpid: "0x8030", bdid: 0x26, displayName: "iPad 9", soc: "t8030", board: "J182AP")
    ]

    private static let normalModeSupport: [String: PurpleModeSupport] = [
        "iPhone11,2": supportedDevices[2],
        "iPhone11,4": supportedDevices[0],
        "iPhone11,6": supportedDevices[3],
        "iPhone11,8": supportedDevices[1],
        "iPad11,1": supportedDevices[4],
        "iPad11,2": supportedDevices[5],
        "iPad11,3": supportedDevices[6],
        "iPad11,4": supportedDevices[7],
        "iPad11,6": supportedDevices[8],
        "iPad11,7": supportedDevices[9],
        "iPhone12,1": supportedDevices[11],
        "iPhone12,3": supportedDevices[12],
        "iPhone12,5": supportedDevices[10],
        "iPhone12,8": supportedDevices[13],
        "iPad12,1": supportedDevices[14],
        "iPad12,2": supportedDevices[15]
    ]

    static func support(cpid: String?, bdid: Int?) -> PurpleModeSupport? {
        guard let cpid, let bdid else {
            return nil
        }
        return supportedDevices.first {
            $0.cpid.caseInsensitiveCompare(cpid) == .orderedSame && $0.bdid == bdid
        }
    }

    static func support(productType: String?) -> PurpleModeSupport? {
        guard let productType else {
            return nil
        }
        return normalModeSupport[productType]
    }
}
