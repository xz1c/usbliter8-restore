import XCTest
@testable import Usb8RestoreSwift

final class ToolResourceTests: XCTestCase {
    func testAllBundledToolsAreFoundAndExecutable() throws {
        for tool in ["idevice_id", "ideviceinfo", "irecovery", "usbliter8ctl"] {
            let url = try XCTUnwrap(AppResourceLocator.toolURL(named: tool), "Missing \(tool)")
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: url.path), "\(tool) is not executable")
        }
    }

    func testBundledIdeviceLibrariesExist() {
        let requiredLibraries = [
            "libcrypto.3.dylib",
            "libimobiledevice-glue.dylib",
            "libimobiledevice.dylib",
            "libplist2.dylib",
            "libssl.3.dylib",
            "libusbmuxd.dylib"
        ]

        for library in requiredLibraries {
            let url = AppResourceLocator.resourceURL(
                name: library.replacingOccurrences(of: ".dylib", with: ""),
                extension: "dylib",
                subdirectories: ["Tools/i4libs", "Resources/Tools/i4libs"]
            )
            XCTAssertNotNil(url, "Missing \(library)")
        }
    }

    func testSelectedIrecoverySupportsCurrentArchitecture() throws {
        let url = try XCTUnwrap(AppResourceLocator.toolURL(named: "irecovery"))
        let expectedArchitecture = currentArchitecture
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        process.arguments = [url.path]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.contains(expectedArchitecture), output)
    }

    func testBundledX86ToolsExistForIntelBuilds() throws {
        let requiredFiles = [
            "idevice_id",
            "ideviceinfo",
            "irecovery",
            "libcrypto.1.1.dylib",
            "libimobiledevice-1.0.dylib",
            "libplist-2.0.dylib",
            "libssl.1.1.dylib",
            "libusbmuxd.dylib"
        ]

        for file in requiredFiles {
            let url = try XCTUnwrap(
                AppResourceLocator.resourceURL(
                    name: fileNameWithoutExtension(file),
                    extension: fileExtension(file),
                    subdirectories: ["Tools/x86_64", "Resources/Tools/x86_64"]
                ),
                "Missing x86_64 resource \(file)"
            )
            XCTAssertTrue(containsArchitecture("x86_64", in: url), "\(file) is not x86_64")
        }
    }

    func testNativeUsbControlToolIsAvailable() throws {
        let ctlURL = try XCTUnwrap(AppResourceLocator.toolURL(named: "usbliter8ctl"))
        let process = Process()
        let pipe = Pipe()
        process.executableURL = ctlURL
        process.arguments = ["--help"]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(process.terminationStatus, 0, output)
        XCTAssertTrue(output.contains("boot"), output)
        XCTAssertTrue(containsArchitecture("x86_64", in: ctlURL), "usbliter8ctl is missing x86_64")
        XCTAssertTrue(containsArchitecture("arm64", in: ctlURL), "usbliter8ctl is missing arm64")
    }

    private var currentArchitecture: String {
        #if arch(x86_64)
        return "x86_64"
        #else
        return "arm64"
        #endif
    }

    private func containsArchitecture(_ architecture: String, in url: URL) -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-archs", url.path]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.split(whereSeparator: \.isWhitespace).contains(Substring(architecture))
    }

    private func fileNameWithoutExtension(_ file: String) -> String {
        (file as NSString).deletingPathExtension
    }

    private func fileExtension(_ file: String) -> String? {
        let ext = (file as NSString).pathExtension
        return ext.isEmpty ? nil : ext
    }
}
