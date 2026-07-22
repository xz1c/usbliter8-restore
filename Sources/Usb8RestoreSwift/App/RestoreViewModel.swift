import Foundation

@MainActor
final class RestoreViewModel: ObservableObject {
    @Published private(set) var device: DetectedDevice?
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var steps = RestoreStep.allCases.map(RestoreStepState.init(step:))
    @Published private(set) var purpleSteps = PurpleModeStep.allCases.map(PurpleModeStepState.init(step:))
    @Published var selectedLogTab: OperationLogTab = .erase
    @Published private(set) var isRunning = false
    @Published var toast: String?
    @Published var language: AppLanguage = .chinese

    private let monitor: DeviceMonitoring
    private let restoreService: RestoreServicing
    private let purpleModeService: PurpleModeServicing

    init(
        monitor: DeviceMonitoring = DeviceMonitor(),
        restoreService: RestoreServicing = RestoreService(),
        purpleModeService: PurpleModeServicing = PurpleModeService()
    ) {
        self.monitor = monitor
        self.restoreService = restoreService
        self.purpleModeService = purpleModeService
    }

    func startMonitoring() async {
        for await detected in monitor.devices() {
            device = detected
            connectionState = ConnectionState(device: detected)
        }
    }

    func startErase() async {
        guard let device else {
            showToast(localized(language, "请连接设备", "Please connect a device"))
            return
        }

        guard device.supportsErase else {
            showToast(localized(language, "设备不支持", "Device not supported"))
            return
        }


        guard device.mode == .pwndfu else {
            showToast(localized(language, "请将设备进入PWNDFU", "Please put the device into PWNDFU"))
            return
        }

        isRunning = true
        selectedLogTab = .erase
        resetSteps()

        do {
            try await restoreService.erase(device: device) { [weak self] completedStep in
                Task { @MainActor in
                    self?.markCompleted(completedStep)
                }
            }
            showToast(localized(language, "抹除成功", "Erase success"))
        } catch {
            if let restoreError = error as? RestoreError, let failedStep = restoreError.failedStep {
                markFailed(failedStep)
            }
            showToast(localizedErrorMessage(error))
        }

        isRunning = false
    }

    func selectLogTab(_ tab: OperationLogTab) {
        selectedLogTab = tab
    }

    func startPurpleMode() async {
        selectedLogTab = .purple
        guard let device else {
            showToast(localized(language, "请连接设备", "Please connect a device"))
            return
        }

        guard device.supportsPurpleMode else {
            showToast(localized(language, "设备不支持", "Device not supported"))
            return
        }


        guard device.mode == .pwndfu else {
            showToast(localized(language, "请将设备进入PWNDFU", "Please put the device into PWNDFU"))
            return
        }

        isRunning = true
        resetPurpleSteps()

        do {
            try await purpleModeService.boot(device: device) { [weak self] completedStep in
                Task { @MainActor in
                    self?.markPurpleCompleted(completedStep)
                }
            }
            showToast(localized(language, "Purple mode 成功", "Purple mode success"))
        } catch {
            if let purpleError = error as? PurpleModeError, let failedStep = purpleError.failedStep {
                markPurpleFailed(failedStep)
            }
            showToast(localizedErrorMessage(error))
        }

        isRunning = false
    }

    private func resetSteps() {
        steps = RestoreStep.allCases.map(RestoreStepState.init(step:))
    }

    private func resetPurpleSteps() {
        purpleSteps = PurpleModeStep.allCases.map(PurpleModeStepState.init(step:))
    }

    private func markCompleted(_ step: RestoreStep) {
        steps = steps.map { state in
            var copy = state
            if copy.step == step {
                copy.status = .completed
            }
            return copy
        }
    }

    private func markFailed(_ step: RestoreStep) {
        steps = steps.map { state in
            var copy = state
            if copy.step == step {
                copy.status = .failed
            }
            return copy
        }
    }

    private func markPurpleCompleted(_ step: PurpleModeStep) {
        purpleSteps = purpleSteps.map { state in
            var copy = state
            if copy.step == step {
                copy.status = .completed
            }
            return copy
        }
    }

    private func markPurpleFailed(_ step: PurpleModeStep) {
        purpleSteps = purpleSteps.map { state in
            var copy = state
            if copy.step == step {
                copy.status = .failed
            }
            return copy
        }
    }

    private func localizedErrorMessage(_ error: Error) -> String {
        if language == .english {
            return error.localizedDescription
        }

        switch error {
        case let error as RestoreError:
            switch error {
            case .missingSupport:
                return "设备不支持"
            case .missingBootAsset:
                return "缺少引导文件"
            case .missingTool(let name):
                return "缺少工具 \(name)"
            case .deviceNotPwndfu:
                return "请将设备进入PWNDFU"
            case .commandFailed(_, let message):
                return message.isEmpty ? "命令执行失败" : message
            case .recoveryTimeout:
                return "等待恢复模式超时"
            case .usbControlFailed(let message):
                return message
            case .needsRepwn:
                return "请重新pwn"
            }
        case let error as PurpleModeError:
            switch error {
            case .missingSupport:
                return "设备不支持"
            case .missingDiagAsset:
                return "缺少Purple资源"
            case .missingTool(let name):
                return "缺少工具 \(name)"
            case .deviceNotPwndfu:
                return "请将设备进入PWNDFU"
            case .commandFailed(_, let message):
                return message.isEmpty ? "命令执行失败" : message
            case .recoveryTimeout:
                return "等待恢复模式超时"
            case .needsRepwn:
                return "请重新pwn"
            }
        default:
            return error.localizedDescription
        }
    }

    private func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if toast == text {
                toast = nil
            }
        }
    }
}
