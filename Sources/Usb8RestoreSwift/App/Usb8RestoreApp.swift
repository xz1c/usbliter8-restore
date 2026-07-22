import SwiftUI

@main
struct Usb8RestoreApp: App {
    @StateObject private var viewModel = RestoreViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(width: 980, height: 618)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
