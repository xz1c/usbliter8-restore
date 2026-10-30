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
            return localized(language, "未连接", "Disconnected", "Не подключено")
        case .normal:
            return localized(language, "正常模式", "Normal Mode", "Обычный режим")
        case .recovery:
            return localized(language, "恢复模式", "Recovery Mode", "Режим восстановления")
        case .dfu:
            return localized(language, "DFU模式", "DFU Mode", "Режим DFU")
        case .pwndfu:
            return localized(language, "PWNDFU模式", "PWNDFU Mode", "Режим PWNDFU")
        }
    }

    var displayText: String {
        displayText(language: .russian)
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
            return localized(language, "未连接", "Disconnected", "Не подключено")
        case .unsupported:
            return localized(language, "设备不支持", "Device not supported", "Устройство не поддерживается")
        case .needsPwndfu:
            return localized(language, "请使用开发板进入PWNDFU", "Use the dev board to enter PWNDFU", "Требуется плата для перехода в PWNDFU")
        case .pwndfuReady:
            return localized(language, "PWNDFU 已就绪", "PWNDFU Ready", "PWNDFU готов")
        }
    }

    var badgeText: String {
        badgeText(language: .russian)
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
            return localized(language, "解析 CPID / BDID / PWND", "Parse CPID / BDID / PWND", "Чтение CPID / BDID / PWND")
        case .confirmPwndfu:
            return localized(language, "确认设备处于 PWNDFU", "Confirm device is in PWNDFU", "Проверка режима PWNDFU")
        case .sendErase:
            return localized(language, "发送抹除", "Send erase command", "Отправка команды стирания")
        case .erasing:
            return localized(language, "抹除中", "Erasing", "Выполняется стирание")
        case .completed:
            return localized(language, "抹除完成", "Erase complete", "Стирание завершено")
        }
    }

    var title: String {
        title(language: .russian)
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
            return localized(language, "抹除", "Erase", "Стирание")
        case .purple:
            return localized(language, "Purple", "Purple", "Режим Purple")
        }
    }

    var title: String {
        title(language: .russian)
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
            return localized(language, "解析 CPID / BDID / PWND", "Parse CPID / BDID / PWND", "Чтение CPID / BDID / PWND")
        case .confirmPwndfu:
            return localized(language, "确认设备处于 PWNDFU", "Confirm device is in PWNDFU", "Проверка режима PWNDFU")
        case .sendDiags:
            return localized(language, "发送 diags", "Send diags", "Отправка diags")
        case .booting:
            return localized(language, "引导中", "Booting", "Загрузка...")
        case .completed:
            return localized(language, "引导完成", "Boot complete", "Загрузка завершена")
        }
    }

    var title: String {
        title(language: .russian)
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
