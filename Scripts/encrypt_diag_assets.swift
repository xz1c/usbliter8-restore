import CryptoKit
import Foundation

private let assetKeySeed = "usb8-restore.diag-assets.v1.local-bundle"

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: encrypt_diag_assets.swift <source-bootchain-dir> <asset-dir>\n".utf8))
    exit(2)
}

let sourceDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let assetDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let fileManager = FileManager.default

if fileManager.fileExists(atPath: assetDirectory.path) {
    try fileManager.removeItem(at: assetDirectory)
}
try fileManager.createDirectory(at: assetDirectory, withIntermediateDirectories: true)

let keyDigest = SHA256.hash(data: Data(assetKeySeed.utf8))
let key = SymmetricKey(data: Data(keyDigest))
var manifestAssets: [[String: Any]] = []

let bootchainURLs = try fileManager
    .subpathsOfDirectory(atPath: sourceDirectory.path)
    .filter { $0.hasSuffix("/ibss.raw") || $0.hasSuffix("/diag.img4") }
    .sorted()

for relativePath in bootchainURLs {
    let sourceURL = sourceDirectory.appendingPathComponent(relativePath)
    let parts = relativePath.split(separator: "/").map(String.init)
    guard parts.count == 3 else {
        continue
    }

    let soc = parts[0]
    let board = parts[1]
    let kind = parts[2] == "ibss.raw" ? "ibss" : "diag"
    let outputRelativePath = "\(soc)/\(board)/\(parts[2]).enc"
    let outputURL = assetDirectory.appendingPathComponent(outputRelativePath)

    try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let plaintext = try Data(contentsOf: sourceURL)
    let sealedBox = try AES.GCM.seal(plaintext, using: key)
    guard let combined = sealedBox.combined else {
        throw NSError(domain: "DiagAssetEncryption", code: 1, userInfo: [NSLocalizedDescriptionKey: "AES-GCM combined data missing"])
    }
    try combined.write(to: outputURL, options: .atomic)

    manifestAssets.append([
        "soc": soc,
        "board": board,
        "kind": kind,
        "file": outputRelativePath,
        "plainSize": plaintext.count
    ])
    print("wrote \(outputRelativePath)")
}

let manifest: [String: Any] = [
    "version": 1,
    "format": "aes-gcm-encrypted-diag-assets",
    "assets": manifestAssets
]
let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try manifestData.write(to: assetDirectory.appendingPathComponent("manifest.json"), options: .atomic)
