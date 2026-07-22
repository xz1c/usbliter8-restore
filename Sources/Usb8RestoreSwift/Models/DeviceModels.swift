import Foundation
import SwiftUI

enum DeviceMode: String, Sendable {
    case disconnected
    case normal
    case recovery
    case dfu
    case pwndfu

    func displayText(language: AppLanguage) -> String {
        switch self {
        case .disconnected:
            return localized(language, "未连接", "Disconnected")
        case .normal:
            return localized(language, "正常模式", "Normal Mode")
        case .recovery:
            return localized(language, "恢复模式", "Recovery Mode")
        case .dfu:
            return localized(language, "DFU模式", "DFU Mode")
        case .pwndfu:
            return localized(language, "PWNDFU模式", "PWNDFU Mode")
        }
    }

    var displayText: String {
        displayText(language: .english)
    }
}

struct DetectedDevice: Equatable, Sendable {
    let displayName: String
    let cpid: String?
    let bdid: Int?
    let ecid: String?
    let udid: String?
    let serialNumber: String?
    let mode: DeviceMode
    let support: DeviceSupport?

    var supportsErase: Bool {
        support != nil
    }

    var purpleSupport: PurpleModeSupport? {
        PurpleModeSupportCatalog.support(cpid: cpid, bdid: bdid)
    }

    var supportsPurpleMode: Bool {
        purpleSupport != nil
    }

    var isSupported: Bool {
        supportsErase || supportsPurpleMode
    }
}

struct DeviceSupport: Equatable, Sendable {
    let cpid: String
    let bdid: Int
    let displayName: String
    let ibecCodename: String
}

enum ConnectionState: Equatable {
    case disconnected
    case unsupported
    case needsPwndfu
    case pwndfuReady

    init(device: DetectedDevice?) {
        guard let device else {
            self = .disconnected
            return
        }

        guard device.isSupported else {
            self = .unsupported
            return
        }

        self = device.mode == .pwndfu ? .pwndfuReady : .needsPwndfu
    }

    var isConnected: Bool {
        self != .disconnected
    }

    func badgeText(language: AppLanguage) -> String {
        switch self {
        case .disconnected:
            return localized(language, "未连接", "Disconnected")
        case .unsupported:
            return localized(language, "设备不支持", "Device not supported")
        case .needsPwndfu:
            return localized(language, "请使用开发板进入PWNDFU", "Use the dev board to enter PWNDFU")
        case .pwndfuReady:
            return localized(language, "PWNDFU 已就绪", "PWNDFU Ready")
        }
    }

    var badgeText: String {
        badgeText(language: .english)
    }

    var badgeForeground: Color {
        switch self {
        case .unsupported:
            return .red
        case .needsPwndfu:
            return .orange
        case .pwndfuReady:
            return .green
        case .disconnected:
            return .secondary
        }
    }

    var badgeBackground: Color {
        badgeForeground.opacity(0.14)
    }
}

enum RestoreStep: Int, CaseIterable, Sendable {
    case parseDevice = 1
    case confirmPwndfu
    case sendErase
    case erasing
    case completed

    func title(language: AppLanguage) -> String {
        switch self {
        case .parseDevice:
            return localized(language, "解析 CPID / BDID / PWND", "Parse CPID / BDID / PWND")
        case .confirmPwndfu:
            return localized(language, "确认设备处于 PWNDFU", "Confirm device is in PWNDFU")
        case .sendErase:
            return localized(language, "发送抹除", "Send erase command")
        case .erasing:
            return localized(language, "抹除中", "Erasing")
        case .completed:
            return localized(language, "抹除完成", "Erase complete")
        }
    }

    var title: String {
        title(language: .english)
    }
}

struct RestoreStepState: Identifiable, Equatable {
    let step: RestoreStep
    var status: RestoreStepStatus = .pending

    init(step: RestoreStep) {
        self.step = step
    }

    var id: Int { step.rawValue }
    var index: Int { step.rawValue }
    var title: String { step.title }
    var isCompleted: Bool { status == .completed }
    var isFailed: Bool { status == .failed }
}

enum RestoreStepStatus: Equatable, Sendable {
    case pending
    case completed
    case failed
}

enum OperationLogTab: String, CaseIterable, Sendable {
    case erase
    case purple

    func title(language: AppLanguage) -> String {
        switch self {
        case .erase:
            return localized(language, "抹除", "Erase")
        case .purple:
            return "Purple"
        }
    }

    var title: String {
        title(language: .english)
    }
}

enum PurpleModeStep: Int, CaseIterable, Sendable {
    case parseDevice = 1
    case confirmPwndfu
    case sendDiags
    case booting
    case completed

    func title(language: AppLanguage) -> String {
        switch self {
        case .parseDevice:
            return localized(language, "解析 CPID / BDID / PWND", "Parse CPID / BDID / PWND")
        case .confirmPwndfu:
            return localized(language, "确认设备处于 PWNDFU", "Confirm device is in PWNDFU")
        case .sendDiags:
            return localized(language, "发送 diags", "Send diags")
        case .booting:
            return localized(language, "引导中", "Booting")
        case .completed:
            return localized(language, "引导完成", "Boot complete")
        }
    }

    var title: String {
        title(language: .english)
    }
}

struct PurpleModeStepState: Identifiable, Equatable {
    let step: PurpleModeStep
    var status: RestoreStepStatus = .pending

    init(step: PurpleModeStep) {
        self.step = step
    }

    var id: Int { step.rawValue }
    var index: Int { step.rawValue }
    var title: String { step.title }
    var isCompleted: Bool { status == .completed }
    var isFailed: Bool { status == .failed }
}
