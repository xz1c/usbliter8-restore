import Foundation

enum DeviceSupportCatalog {
    static let supportedDevices: [DeviceSupport] = [
        DeviceSupport(cpid: "0x8020", bdid: 0x0A, displayName: "iPhone XS Max", ibecCodename: "d331"),
        DeviceSupport(cpid: "0x8020", bdid: 0x0C, displayName: "iPhone XR", ibecCodename: "n841"),
        DeviceSupport(cpid: "0x8020", bdid: 0x0E, displayName: "iPhone XS", ibecCodename: "d321"),
        DeviceSupport(cpid: "0x8020", bdid: 0x1A, displayName: "iPhone XS Max", ibecCodename: "d331p"),
        DeviceSupport(cpid: "0x8020", bdid: 0x14, displayName: "iPad mini 5", ibecCodename: "j210"),
        DeviceSupport(cpid: "0x8020", bdid: 0x16, displayName: "iPad mini 5", ibecCodename: "j210"),
        DeviceSupport(cpid: "0x8020", bdid: 0x1C, displayName: "iPad Air 3", ibecCodename: "j217"),
        DeviceSupport(cpid: "0x8020", bdid: 0x1E, displayName: "iPad Air 3", ibecCodename: "j217"),
        DeviceSupport(cpid: "0x8020", bdid: 0x24, displayName: "iPad 8", ibecCodename: "ipad11b"),
        DeviceSupport(cpid: "0x8020", bdid: 0x26, displayName: "iPad 8", ibecCodename: "ipad11b"),
        DeviceSupport(cpid: "0x8030", bdid: 0x02, displayName: "iPhone 11 Pro Max", ibecCodename: "d431"),
        DeviceSupport(cpid: "0x8030", bdid: 0x04, displayName: "iPhone 11", ibecCodename: "n104"),
        DeviceSupport(cpid: "0x8030", bdid: 0x06, displayName: "iPhone 11 Pro", ibecCodename: "d421"),
        DeviceSupport(cpid: "0x8030", bdid: 0x10, displayName: "iPhone SE 2", ibecCodename: "d79")
    ]

    private static let normalModeSupport: [String: DeviceSupport] = [
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
        "iPhone12,8": supportedDevices[13]
    ]

    static func support(cpid: String?, bdid: Int?) -> DeviceSupport? {
        guard let cpid, let bdid else {
            return nil
        }
        return supportedDevices.first { $0.cpid.caseInsensitiveCompare(cpid) == .orderedSame && $0.bdid == bdid }
    }

    static func support(productType: String?) -> DeviceSupport? {
        guard let productType else {
            return nil
        }
        return normalModeSupport[productType]
    }

    static func displayName(productType: String?) -> String? {
        guard let productType else {
            return nil
        }
        return AppleDeviceModelCatalog.displayName(productType: productType) ?? support(productType: productType)?.displayName
    }
}

enum AppleDeviceModelCatalog {
    private static let displayNames: [String: String] = loadDisplayNames()

    static func displayName(productType: String) -> String? {
        displayNames[productType]
    }

    private static func loadDisplayNames() -> [String: String] {
        let urls = [
            Bundle.main.url(forResource: "apple-mobile-devices", withExtension: "json", subdirectory: "DeviceCatalog"),
            Bundle.main.url(forResource: "apple-mobile-devices", withExtension: "json", subdirectory: "Resources/DeviceCatalog"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sources/Usb8RestoreSwift/Resources/DeviceCatalog/apple-mobile-devices.json")
        ].compactMap { $0 }

        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let catalog = try? JSONDecoder().decode([String: String].self, from: data) else {
                continue
            }
            return catalog
        }

        return [:]
    }
}
