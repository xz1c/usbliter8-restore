import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var viewModel: RestoreViewModel
    @State private var language: AppLanguage = .russian

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                TitleBar(language: language) {
                    language.toggle()
                    viewModel.language = language
                }

                HStack(spacing: 0) {
                    SidebarView(language: language)
                        .frame(width: 216)

                    MainPanel(viewModel: viewModel, language: language)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(WindowConfigurator())
        .onAppear {
            viewModel.language = language
            Task {
                await viewModel.startMonitoring()
            }
        }
    }
}

private struct TitleBar: View {
    let language: AppLanguage
    let onToggleLanguage: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                WindowControlButton(color: Color(red: 1.0, green: 0.34, blue: 0.34), action: .close)
                WindowControlButton(color: Color(red: 1.0, green: 0.76, blue: 0.12), action: .minimize)
                WindowControlButton(color: Color(red: 0.20, green: 0.78, blue: 0.34), action: .zoom)
                Spacer()
                Button(action: onToggleLanguage) {
                    Text(language.toggleTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.10, green: 0.13, blue: 0.22))
                        .frame(width: 54, height: 28)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.56))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 18)
            }
            .padding(.leading, 18)

            Text("usb8 restore")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(red: 0.10, green: 0.13, blue: 0.22))
        }
        .frame(height: 54)
        .background(Color.white.opacity(0.42))
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

private struct SidebarView: View {
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 12) {
                SidebarLogo()

                Text("usb8\nrestore")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(Color(red: 0.10, green: 0.13, blue: 0.22))
                    .lineSpacing(-3)
            }
            .padding(.top, 25)

            VStack(spacing: 10) {
                SidebarItem(title: localized(language, "设备", "Device", "Устройство"), icon: "iphone", selected: true)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.22))
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

private struct SidebarLogo: View {
    var body: some View {
        ZStack {
            if let image = SidebarLogoLoader.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 9)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.66, blue: 1.0),
                                Color(red: 0.38, green: 0.28, blue: 0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "bolt.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .shadow(color: Color.black.opacity(0.14), radius: 12, y: 7)
    }
}

private enum SidebarLogoLoader {
    static let image: NSImage? = {
        guard let url = AppResourceLocator.resourceURL(
            name: "sidebar-logo",
            extension: "png",
            subdirectories: ["AppLogo", "Resources/AppLogo"]
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
}

private struct SidebarItem: View {
    let title: String
    let icon: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 19)

            Text(title)
                .font(.system(size: 14, weight: .bold))

            Spacer()
        }
        .foregroundColor(Color(red: 0.09, green: 0.33, blue: 0.86))
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Color(red: 0.55, green: 0.48, blue: 0.95).opacity(0.16) : Color.clear)
        )
    }
}

private struct MainPanel: View {
    @ObservedObject var viewModel: RestoreViewModel
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .center) {
                Text(displayTitle)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(red: 0.10, green: 0.13, blue: 0.22))

                Spacer()

                StatusBadge(state: viewModel.connectionState, language: language)
            }

            HStack(spacing: 22) {
                DeviceCardView(device: viewModel.device, actionToast: viewModel.toast, language: language)
                    .frame(width: 431)

                ExecutionCardView(
                    selectedTab: viewModel.selectedLogTab,
                    eraseSteps: viewModel.steps,
                    purpleSteps: viewModel.purpleSteps,
                    onSelectTab: viewModel.selectLogTab,
                    language: language
                )
                    .frame(width: 246)
            }
            .frame(height: 332)

            DangerActionView(
                isRunning: viewModel.isRunning,
                language: language,
                purpleAction: {
                    Task { await viewModel.startPurpleMode() }
                }
            ) {
                Task { await viewModel.startErase() }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 30)
        .padding(.horizontal, 32)
        .background(Color.white.opacity(0.12))
    }

    private var displayTitle: String {
        viewModel.connectionState.isConnected ? localized(language, "设备已连接", "Device Connected", "Устройство подключено") : localized(language, "请连接设备", "Please connect a device", "Подключите устройство")
    }
}

private struct StatusBadge: View {
    let state: ConnectionState
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state == .pwndfuReady ? Color(red: 0.05, green: 0.58, blue: 0.34) : Color(red: 0.56, green: 0.60, blue: 0.67))
                .frame(width: 8, height: 8)

            Text(state == .pwndfuReady ? localized(language, "PWNDFU 已就绪", "PWNDFU Ready", "PWNDFU готов") : state.badgeText(language: language))
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(state == .pwndfuReady ? Color(red: 0.04, green: 0.45, blue: 0.25) : Color(red: 0.35, green: 0.38, blue: 0.45))
        .padding(.horizontal, 13)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(state == .pwndfuReady ? Color(red: 0.08, green: 0.62, blue: 0.36).opacity(0.10) : Color.white.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(state == .pwndfuReady ? Color(red: 0.08, green: 0.62, blue: 0.36).opacity(0.25) : Color.black.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct DeviceCardView: View {
    let device: DetectedDevice?
    let actionToast: String?
    let language: AppLanguage
    @State private var copyToast: String?

    var body: some View {
        HStack(spacing: 22) {
            PhonePreview()
                .frame(width: 136)

            VStack(alignment: .leading, spacing: 17) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.10, green: 0.13, blue: 0.22))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    if let modeText {
                        Text(modeText)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.35, green: 0.39, blue: 0.48))
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.55))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .fixedSize()
                    }
                }
                .frame(width: 230, alignment: .leading)

                HStack(spacing: 9) {
                    if let device {
                        Pill(text: device.supportsErase ? localized(language, "抹除支持", "Erase Supported", "Стирание поддерживается") : localized(language, "抹除不支持", "Erase Unsupported", "Стирание не поддерживается"), style: device.supportsErase ? .ready : .muted)
                        Pill(text: device.supportsPurpleMode ? localized(language, "Purple 支持", "Purple Supported", "Purple поддерживается") : localized(language, "Purple 不支持", "Purple Unsupported", "Purple не поддерживается"), style: device.supportsPurpleMode ? .ready : .muted)
                    } else {
                        Pill(text: localized(language, "未连接设备", "No Device Connected", "Устройство не подключено"), style: .muted)
                    }
                }

                VStack(spacing: 8) {
                    VStack(spacing: 10) {
                        ForEach(infoRows, id: \.title) { row in
                            InfoRow(title: row.title, value: row.value, language: language, onCopied: showCopyToast)
                        }
                    }

                    ZStack {
                        if let visibleToast {
                            CopyToastView(text: visibleToast)
                                .transition(.scale(scale: 0.94).combined(with: .opacity))
                        }
                    }
                    .frame(width: 229, height: 30)
                }
            }
            .frame(width: 230, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .frame(width: 431, height: 332)
        .background(CardBackground(cornerRadius: 16))
        .animation(.easeOut(duration: 0.18), value: visibleToast)
    }

    private var visibleToast: String? {
        copyToast ?? actionToast
    }

    private var displayName: String {
        guard let device else {
            return localized(language, "设备未连接", "Device Disconnected", "Устройство отключено")
        }

        return device.displayName
    }

    private var modeText: String? {
        device?.mode.displayText(language: language)
    }

    private var infoRows: [(title: String, value: String)] {
        guard let device else {
            return [
                ("ECID", localized(language, "未获取", "Not Available", "Нет данных")),
                ("UDID", localized(language, "未获取", "Not Available", "Нет данных")),
                ("SN", localized(language, "未获取", "Not Available", "Нет данных"))
            ]
        }

        return [
            ("ECID", device.ecid ?? localized(language, "未获取", "Not Available", "Нет данных")),
            ("UDID", device.udid ?? localized(language, "未获取", "Not Available", "Нет данных")),
            ("SN", device.serialNumber ?? localized(language, "未获取", "Not Available", "Нет данных"))
        ]
    }

    private func showCopyToast(_ title: String) {
        copyToast = localized(language, "\(title) 已复制", "\(title) Copied", "\(title) скопировано")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            if copyToast == localized(language, "\(title) 已复制", "\(title) Copied", "\(title) скопировано") {
                copyToast = nil
            }
        }
    }
}

private struct PhonePreview: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.05, green: 0.08, blue: 0.14))
                .frame(width: 106, height: 184)
                .shadow(color: Color.black.opacity(0.20), radius: 22, y: 14)

            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.21, green: 0.37, blue: 0.58),
                            Color(red: 0.08, green: 0.25, blue: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 90, height: 168)

            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 37, height: 5)
                .offset(y: -72)

            Circle()
                .trim(from: 0.12, to: 0.92)
                .stroke(Color.white.opacity(0.72), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(18))
        }
    }
}

private struct Pill: View {
    enum Style {
        case ready
        case muted
    }

    let text: String
    var style: Style = .ready

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(background)
            )
            .overlay(
                Capsule()
                    .stroke(stroke, lineWidth: 1)
            )
    }

    private var foreground: Color {
        switch style {
        case .ready:
            return Color(red: 0.02, green: 0.46, blue: 0.28)
        case .muted:
            return Color(red: 0.42, green: 0.46, blue: 0.55)
        }
    }

    private var background: Color {
        switch style {
        case .ready:
            return Color(red: 0.06, green: 0.60, blue: 0.36).opacity(0.09)
        case .muted:
            return Color(red: 0.44, green: 0.48, blue: 0.56).opacity(0.08)
        }
    }

    private var stroke: Color {
        switch style {
        case .ready:
            return Color(red: 0.06, green: 0.60, blue: 0.36).opacity(0.20)
        case .muted:
            return Color(red: 0.44, green: 0.48, blue: 0.56).opacity(0.16)
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    let language: AppLanguage
    let onCopied: (String) -> Void
    private var canCopy: Bool {
        value != localized(language, "未获取", "Not Available", "Нет данных")
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(red: 0.40, green: 0.44, blue: 0.54))
                .frame(width: 42, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.23))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                copyValue()
            } label: {
                Text(localized(language, "复制", "Copy", "Коп."))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(canCopy ? Color(red: 0.20, green: 0.37, blue: 0.85) : Color(red: 0.58, green: 0.61, blue: 0.68))
                    .frame(width: 34, height: 24)
                    .background(
                        Capsule()
                            .fill(canCopy ? Color(red: 0.20, green: 0.42, blue: 1.0).opacity(0.10) : Color.black.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canCopy)
            .help(canCopy ? localized(language, "复制完整\(title)", "Copy full \(title)", "Копировать полностью: \(title)") : localized(language, "\(title)未获取", "\(title) not available", "\(title): нет данных"))
        }
        .padding(.horizontal, 12)
        .frame(width: 229, height: 39)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
    }

    private func copyValue() {
        guard canCopy else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        onCopied(title)
    }
}

private struct CopyToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Color(red: 0.04, green: 0.42, blue: 0.25))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(Color(red: 0.80, green: 0.96, blue: 0.86).opacity(0.92))
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.16, green: 0.68, blue: 0.38).opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.08, green: 0.50, blue: 0.26).opacity(0.10), radius: 14, y: 7)
            )
    }
}

private struct ExecutionCardView: View {
    let selectedTab: OperationLogTab
    let eraseSteps: [RestoreStepState]
    let purpleSteps: [PurpleModeStepState]
    let onSelectTab: (OperationLogTab) -> Void
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 7) {
                ForEach(OperationLogTab.allCases, id: \.self) { tab in
                    Button {
                        onSelectTab(tab)
                    } label: {
                        Text(tab.title(language: language))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(selectedTab == tab ? .white : Color(red: 0.42, green: 0.48, blue: 0.60))
                            .frame(width: language == .russian ? (tab == .purple ? 112 : 88) : 72, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == tab ? Color(red: 0.92, green: 0.18, blue: 0.31) : Color.white.opacity(0.54))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 18) {
                if selectedTab == .erase {
                    ForEach(eraseSteps) { step in
                        StepRow(index: step.index, title: step.step.title(language: language), isCompleted: step.isCompleted, isFailed: step.isFailed)
                    }
                } else {
                    ForEach(purpleSteps) { step in
                        StepRow(index: step.index, title: step.step.title(language: language), isCompleted: step.isCompleted, isFailed: step.isFailed)
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 21)
        .padding(.horizontal, 21)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CardBackground(cornerRadius: 16))
    }
}

private struct StepRow: View {
    let index: Int
    let title: String
    let isCompleted: Bool
    let isFailed: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(stepColor)
                    .frame(width: 20, height: 20)

                Text("\(index)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isCompleted || isFailed ? .white : Color(red: 0.10, green: 0.33, blue: 0.90))
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isFailed ? Color(red: 0.86, green: 0.12, blue: 0.22) : Color(red: 0.40, green: 0.44, blue: 0.54))
        }
    }

    private var stepColor: Color {
        if isFailed {
            return Color(red: 0.90, green: 0.16, blue: 0.26)
        }
        if isCompleted {
            return Color(red: 0.10, green: 0.68, blue: 0.38)
        }
        return Color(red: 0.62, green: 0.75, blue: 1.0)
    }
}

private struct DangerActionView: View {
    let isRunning: Bool
    let language: AppLanguage
    let purpleAction: () -> Void
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localized(language, "危险操作需要再次确认", "Dangerous operations require confirmation", "Подтвердите опасное действие"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.10, green: 0.13, blue: 0.22))

                Text(localized(language, "如设备处于 DFU、恢复模式或正常模式，请使用开发板进入PWNDFU", "If the device is in DFU, recovery, or normal mode, use the dev board to enter PWNDFU", "Для продолжения требуется режим PWNDFU."))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.40, green: 0.44, blue: 0.54))
            }

            Spacer()

            HStack(spacing: 14) {
                DangerActionButton(title: localized(language, "Purple mode", "Purple mode", "Режим Purple"), action: purpleAction)
                    .disabled(isRunning)

                DangerActionButton(title: isRunning ? localized(language, "执行中", "Running", "Выполняется") : localized(language, "开始抹除", "Erase Device", "Начать стирание"), action: action)
                    .disabled(isRunning)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 84)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.48))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.96, green: 0.28, blue: 0.38).opacity(0.20), lineWidth: 1)
                )
                .shadow(color: Color(red: 0.88, green: 0.20, blue: 0.34).opacity(0.08), radius: 18, y: 10)
        )
    }
}

private struct DangerActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(background)

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(width: 126, height: 38)
        }
        .buttonStyle(.plain)
    }

    private var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.92, green: 0.18, blue: 0.31),
                Color(red: 0.84, green: 0.12, blue: 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct CardBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.44))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.68, green: 0.28, blue: 0.40).opacity(0.06), radius: 24, y: 10)
    }
}

private struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(Color(red: 0.10, green: 0.13, blue: 0.22))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(CardBackground(cornerRadius: 10))
    }
}

private enum WindowControlAction {
    case close
    case minimize
    case zoom
}

private struct WindowControlButton: View {
    let color: Color
    let action: WindowControlAction

    var body: some View {
        Button {
            guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
                return
            }

            switch action {
            case .close:
                window.close()
            case .minimize:
                window.miniaturize(nil)
            case .zoom:
                window.zoom(nil)
            }
        } label: {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        }
        .buttonStyle(.plain)
    }
}

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.88, blue: 0.92),
                Color(red: 1.0, green: 0.96, blue: 0.98),
                Color(red: 0.94, green: 0.98, blue: 0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.72, blue: 0.82).opacity(0.26),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 520
            )
        )
        .ignoresSafeArea()
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: view.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.resizable)
        window.setContentSize(NSSize(width: 980, height: 618))
        window.minSize = NSSize(width: 980, height: 618)
        window.maxSize = NSSize(width: 980, height: 618)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}
