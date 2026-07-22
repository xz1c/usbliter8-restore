import Foundation
import IOKit
import IOKit.usb

protocol DeviceMonitoring: Sendable {
    func devices() -> AsyncStream<DetectedDevice?>
}

struct DeviceMonitor: DeviceMonitoring {
    func devices() -> AsyncStream<DetectedDevice?> {
        AsyncStream { continuation in
            let task = Task.detached {
                while !Task.isCancelled {
                    continuation.yield(await detectOnce())
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func detectOnce() async -> DetectedDevice? {
        MobileDeviceToolReader.detectNormalModeDevice()
            ?? USBDeviceScanner.detectAppleDevice()
    }
}

private enum USBDeviceScanner {
    private static let appleVendorID = 0x05AC
    private static let dfuProductID = 0x1227
    private static let recoveryProductIDs: Set<Int> = [0x1280, 0x1281, 0x1282, 0x1283]
    private static let mobileProductIDs: Set<Int> = [
        0x1290, 0x1291, 0x1292, 0x1293, 0x1294, 0x1295, 0x1296, 0x1297,
        0x12A0, 0x12A1, 0x12A2, 0x12A3, 0x12A4, 0x12A5, 0x12A6, 0x12A7,
        0x12A8, 0x12A9, 0x12AA, 0x12AB
    ]
    private static let ignoredProductNames = [
        "kanziswd",
        "brisket",
        "pico",
        "usb hub",
        "keyboard",
        "mouse",
        "trackpad"
    ]

    static func detectAppleDevice() -> DetectedDevice? {
        let matching = IOServiceMatching(kIOUSBDeviceClassName)
        var iterator: io_iterator_t = 0

        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var candidates: [USBDeviceCandidate] = []
        var bestFallback: USBDeviceCandidate?

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            guard integerProperty("idVendor", service: service) == appleVendorID else {
                continue
            }

            let productID = integerProperty("idProduct", service: service)
            let productName = stringProperty("USB Product Name", service: service)
                ?? stringProperty("Product Name", service: service)
                ?? ""
            let serial = stringProperty("USB Serial Number", service: service)
                ?? stringProperty("Serial Number", service: service)
                ?? ""
            let sessionID = unsignedIntegerProperty("sessionID", service: service)
            let locationID = unsignedIntegerProperty("locationID", service: service)
            let registryID = registryEntryID(service)

            if productID == dfuProductID {
                let device = dfuDevice(from: serial)
                candidates.append(
                    USBDeviceCandidate(
                        device: device,
                        priority: device.mode == .pwndfu ? 4 : 3,
                        sessionID: sessionID,
                        locationID: locationID,
                        registryID: registryID
                    )
                )
                continue
            }

            guard isMobileDevice(productID: productID, productName: productName) else {
                continue
            }

            let device = normalOrRecoveryDevice(serial: serial, productID: productID, productName: productName)
            let candidate = USBDeviceCandidate(
                device: device,
                priority: device.mode == .recovery ? 2 : 1,
                sessionID: sessionID,
                locationID: locationID,
                registryID: registryID
            )
            if bestFallback == nil || candidate.isPreferred(over: bestFallback) {
                bestFallback = candidate
            }
        }

        return candidates.sorted(by: { $0.isPreferred(over: $1) }).first?.device ?? bestFallback?.device
    }

    private struct USBDeviceCandidate {
        let device: DetectedDevice
        let priority: Int
        let sessionID: UInt64
        let locationID: UInt64
        let registryID: UInt64

        func isPreferred(over other: USBDeviceCandidate?) -> Bool {
            guard let other else {
                return true
            }

            if priority != other.priority {
                return priority > other.priority
            }
            if sessionID != other.sessionID {
                return sessionID > other.sessionID
            }
            if registryID != other.registryID {
                return registryID > other.registryID
            }
            return locationID > other.locationID
        }
    }

    private static func dfuDevice(from serial: String) -> DetectedDevice {
        let info = DFUSerialParser.parse(serial)
        let support = DeviceSupportCatalog.support(cpid: info.cpid, bdid: info.bdid)
        let purpleSupport = PurpleModeSupportCatalog.support(cpid: info.cpid, bdid: info.bdid)
        let mode: DeviceMode = info.isPwndfu ? .pwndfu : .dfu

        return DetectedDevice(
            displayName: support?.displayName ?? purpleSupport?.displayName ?? "Apple Device",
            cpid: info.cpid,
            bdid: info.bdid,
            ecid: ECIDFormatter.displayString(from: info.ecid),
            udid: nil,
            serialNumber: info.serialNumber,
            mode: mode,
            support: support
        )
    }

    private static func normalOrRecoveryDevice(serial: String, productID: Int?, productName: String) -> DetectedDevice {
        let mode: DeviceMode = productID.map(recoveryProductIDs.contains) == true ? .recovery : .normal
        if mode == .recovery {
            return recoveryDevice(from: serial, productName: productName)
        }

        return DetectedDevice(
            displayName: displayName(from: productName),
            cpid: nil,
            bdid: nil,
            ecid: nil,
            udid: nil,
            serialNumber: serial.isEmpty ? nil : serial,
            mode: mode,
            support: nil
        )
    }

    private static func recoveryDevice(from serial: String, productName: String) -> DetectedDevice {
        let info = DFUSerialParser.parse(serial)
        let support = DeviceSupportCatalog.support(cpid: info.cpid, bdid: info.bdid)
        let purpleSupport = PurpleModeSupportCatalog.support(cpid: info.cpid, bdid: info.bdid)

        return DetectedDevice(
            displayName: support?.displayName ?? purpleSupport?.displayName ?? displayName(from: productName),
            cpid: info.cpid,
            bdid: info.bdid,
            ecid: ECIDFormatter.displayString(from: info.ecid),
            udid: nil,
            serialNumber: info.serialNumber,
            mode: .recovery,
            support: support
        )
    }

    private static func isMobileDevice(productID: Int?, productName: String) -> Bool {
        let lowercasedName = productName.lowercased()
        if ignoredProductNames.contains(where: lowercasedName.contains) {
            return false
        }

        if let productID, recoveryProductIDs.contains(productID) || mobileProductIDs.contains(productID) {
            return true
        }

        return lowercasedName.contains("iphone")
            || lowercasedName.contains("ipad")
            || lowercasedName.contains("ipod")
            || lowercasedName.contains("apple mobile")
            || lowercasedName.contains("recovery")
    }

    private static func displayName(from productName: String) -> String {
        let trimmed = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Apple Device" : trimmed
    }

    private static func integerProperty(_ key: String, service: io_service_t) -> Int? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return nil
    }

    private static func unsignedIntegerProperty(_ key: String, service: io_service_t) -> UInt64 {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() else {
            return 0
        }

        if let number = value as? NSNumber {
            return number.uint64Value
        }

        return 0
    }

    private static func registryEntryID(_ service: io_service_t) -> UInt64 {
        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &entryID)
        return entryID
    }

    private static func stringProperty(_ key: String, service: io_service_t) -> String? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() else {
            return nil
        }

        return value as? String
    }
}

private enum MobileDeviceToolReader {
    static func detectNormalModeDevice() -> DetectedDevice? {
        guard let ideviceID = findTool(named: "idevice_id"),
              let udid = run(ideviceID, arguments: ["-l"]).firstNonEmptyLine else {
            return nil
        }

        let info = readDeviceInfo(udid: udid)
        let productType = info["ProductType"]
        let displayName = displayName(deviceName: info["DeviceName"], productType: productType)
        let support = DeviceSupportCatalog.support(productType: productType)
        let purpleSupport = PurpleModeSupportCatalog.support(productType: productType)

        return DetectedDevice(
            displayName: displayName,
            cpid: support?.cpid ?? purpleSupport?.cpid,
            bdid: support?.bdid ?? purpleSupport?.bdid,
            ecid: ECIDFormatter.displayString(from: info["UniqueChipID"]),
            udid: info["UniqueDeviceID"] ?? udid,
            serialNumber: info["SerialNumber"],
            mode: .normal,
            support: support
        )
    }

    private static func readDeviceInfo(udid: String) -> [String: String] {
        guard let ideviceInfo = findTool(named: "ideviceinfo") else {
            return ["UniqueDeviceID": udid]
        }

        var values: [String: String] = ["UniqueDeviceID": udid]
        for key in ["DeviceName", "ProductType", "ProductVersion", "SerialNumber", "UniqueDeviceID", "UniqueChipID"] {
            let output = run(ideviceInfo, arguments: ["-u", udid, "-k", key])
            let value = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, !value.lowercased().contains("error:") {
                values[key] = value
            }
        }
        return values
    }

    private static func displayName(deviceName: String?, productType: String?) -> String {
        if let productType, let modelName = DeviceSupportCatalog.displayName(productType: productType) {
            return modelName
        }

        if let productType {
            let trimmed = productType.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let deviceName {
            let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return "iPhone / iPad"
    }

    private static func findTool(named name: String) -> String? {
        AppResourceLocator.toolURL(named: name)?.path
    }

    private static func run(_ launchPath: String, arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum ECIDFormatter {
    static func displayString(from rawValue: String?) -> String? {
        guard let rawValue else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let decimal = UInt64(trimmed) {
            return String(format: "%016llX", decimal)
        }

        let hex = trimmed
            .replacingOccurrences(of: "0x", with: "", options: .caseInsensitive)
            .uppercased()
        guard !hex.isEmpty else {
            return nil
        }

        return hex.count >= 16 ? hex : String(repeating: "0", count: 16 - hex.count) + hex
    }
}

private extension String {
    var firstNonEmptyLine: String? {
        split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
