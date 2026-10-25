import Foundation

@MainActor
final class AppCoordinator {
    let monitor = MissionControlMonitor()
    func stop() { monitor.stop() }
}
