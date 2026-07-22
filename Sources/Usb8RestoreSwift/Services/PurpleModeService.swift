import Foundation

protocol PurpleModeServicing: Sendable {
    func boot(
        device: DetectedDevice,
        progress: @Sendable @escaping (PurpleModeStep) -> Void
    ) async throws
}

enum PurpleModeError: LocalizedError {
    case missingSupport
    case missingDiagAsset
    case missingTool(String)
    case deviceNotPwndfu
    case commandFailed(step: PurpleModeStep, message: String)
    case recoveryTimeout
    case needsRepwn(step: PurpleModeStep, message: String)

    var errorDescription: String? {
        switch self {
        case .missingSupport:
            return "Device not supported"
        case .missingDiagAsset:
            return "Missing Purple assets"
        case let .missingTool(name):
            return "Missing tool \(name)"
        case .deviceNotPwndfu:
            return "Please put the device into PWNDFU"
        case let .commandFailed(_, message):
            return message.isEmpty ? "Command failed" : message
        case .recoveryTimeout:
            return "Timed out waiting for recovery mode"
        case .needsRepwn:
            return "Please re-pwn"
        }
    }

    var failedStep: PurpleModeStep? {
        switch self {
        case let .needsRepwn(step, _):
            return step
        case .missingSupport:
            return .parseDevice
        case .missingDiagAsset, .missingTool, .deviceNotPwndfu:
            return .confirmPwndfu
        case let .commandFailed(step, _):
            return step
        case .recoveryTimeout:
            return .sendDiags
        }
    }
}

struct PurpleModeService: PurpleModeServicing {
    private let assets = PurpleModeAssetStore()

    func boot(
        device: DetectedDevice,
        progress: @Sendable @escaping (PurpleModeStep) -> Void
    ) async throws {
        guard let support = PurpleModeSupportCatalog.support(cpid: device.cpid, bdid: device.bdid) else {
            throw PurpleModeError.missingSupport
        }

        guard device.mode == .pwndfu else {
            throw PurpleModeError.deviceNotPwndfu
        }

        progress(.parseDevice)
        progress(.confirmPwndfu)

        let decryptedAssets = try assets.decryptedAssets(for: support)
        defer { decryptedAssets.removeTemporaryFiles() }

        let irecoveryURL = try requiredToolURL(named: "irecovery")
        let usbliter8ctlURL = try requiredToolURL(named: "usbliter8ctl")

        progress(.sendDiags)
        do {
            try await PurpleCommandRunner.run(
                usbliter8ctlURL,
                arguments: ["boot", decryptedAssets.ibssURL.path],
                failedStep: .sendDiags,
                environment: AppResourceLocator.pythonToolEnvironment()
            )
        } catch PurpleModeError.commandFailed(_, let output) where Usbliter8BootOutput.needsRepwn(output) {
            throw PurpleModeError.needsRepwn(step: .sendDiags, message: output)
        }

        try await waitForRecovery(irecoveryURL: irecoveryURL)

        progress(.booting)
        try await PurpleCommandRunner.run(
            irecoveryURL,
            arguments: ["-c", "setenvnp boot-args usbserial=enable"],
            failedStep: .booting
        )
        try await PurpleCommandRunner.run(
            irecoveryURL,
            arguments: ["-c", "saveenv"],
            failedStep: .booting
        )
        try await PurpleCommandRunner.run(
            irecoveryURL,
            arguments: ["-f", decryptedAssets.diagURL.path],
            failedStep: .booting
        )
        try await PurpleCommandRunner.run(
            irecoveryURL,
            arguments: ["-c", "go"],
            allowFailureFor: true,
            failedStep: .booting
        )

        progress(.completed)
    }

    private func requiredToolURL(named name: String) throws -> URL {
        guard let url = AppResourceLocator.toolURL(named: name) else {
            throw PurpleModeError.missingTool(name)
        }
        return url
    }

    private func waitForRecovery(irecoveryURL: URL) async throws {
        for _ in 0..<60 {
            let result = try? await PurpleCommandRunner.capture(irecoveryURL, arguments: ["-m"])
            if result?.localizedCaseInsensitiveContains("Recovery") == true {
                return
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw PurpleModeError.recoveryTimeout
    }
}

private enum PurpleCommandRunner {
    static func run(
        _ executableURL: URL,
        arguments: [String],
        allowFailureFor allowFailure: Bool = false,
        failedStep: PurpleModeStep,
        environment: [String: String]? = nil
    ) async throws {
        let result = try await execute(executableURL, arguments: arguments, environment: environment)
        if result.status != 0 && !allowFailure {
            throw PurpleModeError.commandFailed(step: failedStep, message: result.output)
        }
    }

    static func capture(_ executableURL: URL, arguments: [String]) async throws -> String {
        try await execute(executableURL, arguments: arguments, environment: nil).output
    }

    private static func execute(_ executableURL: URL, arguments: [String], environment: [String: String]?) async throws -> (status: Int32, output: String) {
        try await Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            if let environment {
                process.environment = environment
            }
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        }.value
    }
}
