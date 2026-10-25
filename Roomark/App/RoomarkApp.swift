import SwiftUI

@main
struct RoomarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            DiagnosticsView(monitor: delegate.coordinator.monitor)
        }
        .defaultSize(width: 720, height: 540)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
