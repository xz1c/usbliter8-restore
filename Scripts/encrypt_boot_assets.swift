import CryptoKit
import Foundation

private let assetKeySeed = "usb8-restore.boot-assets.v1.local-bundle"

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: encrypt_boot_assets.swift <source-boot-dir> <asset-dir>\n".utf8))
    exit(2)
}

let sourceDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let assetDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let fileManager = FileManager.default
try fileManager.createDirectory(at: assetDirectory, withIntermediateDirectories: true)

let sourceURLs = try fileManager
    .contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.hasPrefix("iBEC.") && $0.lastPathComponent.hasSuffix(".RELEASE.patched") }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

let keyDigest = SHA256.hash(data: Data(assetKeySeed.utf8))
let key = SymmetricKey(data: Data(keyDigest))
var manifestAssets: [[String: String]] = []

for sourceURL in sourceURLs {
    let name = sourceURL.lastPathComponent
    let codename = name
        .replacingOccurrences(of: "iBEC.", with: "")
        .replacingOccurrences(of: ".RELEASE.patched", with: "")
    let plaintext = try Data(contentsOf: sourceURL)
    let sealedBox = try AES.GCM.seal(plaintext, using: key)
    guard let combined = sealedBox.combined else {
        throw NSError(domain: "BootAssetEncryption", code: 1, userInfo: [NSLocalizedDescriptionKey: "AES-GCM combined data missing"])
    }

    let outputName = "\(codename).ibec.enc"
    try combined.write(to: assetDirectory.appendingPathComponent(outputName), options: .atomic)
    manifestAssets.append(["codename": codename, "file": outputName])
    print("wrote \(outputName)")
}

let manifest: [String: Any] = [
    "version": 1,
    "format": "aes-gcm-encrypted-ibec-assets",
    "assets": manifestAssets
]
let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try manifestData.write(to: assetDirectory.appendingPathComponent("manifest.json"), options: .atomic)
