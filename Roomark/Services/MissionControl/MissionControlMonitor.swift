import AppKit
import Combine
import OSLog

/// A bounded diagnostic session, not a production background monitor.
@MainActor
final class MissionControlMonitor: ObservableObject {
    @Published private(set) var snapshot = SpaceSnapshot.empty
    @Published private(set) var isRunning = false
    @Published private(set) var status = "尚未启动验证"
    @Published private(set) var details = ""
    @Published private(set) var richestScan = ""
    @Published private(set) var permissionGranted = false
    private let provider: any SpaceProvider
    private let reader = MissionControlAccessibilityReader()
    private let overlay = OverlayCoordinator()
    private var timer: Timer?
    private var mouseMonitor: Any?
    private var interval: TimeInterval = 0
    private var burstUntil: TimeInterval = 0
    private var nextSnapshotRead: TimeInterval = 0
    private var previousButtons: [MissionControlDesktopButton] = []
    private var lastOverlayFrame: CGRect?
    private var deadline: TimeInterval = 0
    private var previousSnapshot: SpaceSnapshot?
    private var largestScanLength = 0
    private var strongestEvidenceRank = -1
    private var lastScanState: MissionControlScan.State?
    private var nextDetailsUpdate: TimeInterval = 0
    private var nextGeometryLog: TimeInterval = 0
    private var metricsStarted: TimeInterval = 0
    private var scanCount = 0
    private var scanSeconds: TimeInterval = 0
    private var slowestScan: TimeInterval = 0
    private let logger = Logger(subsystem: "local.roomark.Roomark", category: "CoreProbe")

    init(provider: any SpaceProvider = SpacePreferencesReader()) { self.provider = provider }

    func refresh() {
        permissionGranted = AccessibilityPermission.isGranted
        do { snapshot = try provider.readSnapshot() }
        catch { snapshot = .empty; status = error.localizedDescription }
    }

    func start() {
        stop()
        refresh()
        guard permissionGranted else { status = "请先授予 Roomark 辅助功能权限。"; return }
        isRunning = true
        logger.notice("Core probe started; accessibility permission granted.")
        richestScan = ""
        largestScanLength = 0
        strongestEvidenceRank = -1
        lastScanState = nil
        deadline = ProcessInfo.processInfo.systemUptime + 90
        nextSnapshotRead = ProcessInfo.processInfo.systemUptime + 0.5
        metricsStarted = ProcessInfo.processInfo.systemUptime
        scanCount = 0
        scanSeconds = 0
        slowestScan = 0
        status = "请打开 Mission Control；验证最多运行 90 秒。"
        // Listen only; no events are intercepted, generated, or retained.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp, .rightMouseUp]) { [weak self] event in
            let released = event.type == .leftMouseUp || event.type == .rightMouseUp
            Task { @MainActor [weak self] in
                guard let self, self.isRunning, self.lastScanState == .desktopListFound else { return }
                if released {
                    self.overlay.hide()
                    self.lastOverlayFrame = nil
                }
                self.burstUntil = ProcessInfo.processInfo.systemUptime + 0.5
                if self.interval != 1.0 / 60 {
                    self.schedule(interval: 1.0 / 60)
                    self.tick()
                }
            }
        }
        tick()
    }

    private func schedule(interval newInterval: TimeInterval) {
        guard interval != newInterval || timer == nil else { return }
        timer?.invalidate()
        interval = newInterval
        timer = Timer(timeInterval: newInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        timer?.tolerance = newInterval * 0.1
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        interval = 0
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        isRunning = false
        previousSnapshot = nil
        previousButtons = []
        reader.reset()
        lastOverlayFrame = nil
        lastScanState = nil
        overlay.hide()
        status = "验证已停止，覆盖层已移除。"
        logger.notice("Core probe stopped; overlay hidden.")
    }

    private func tick() {
        guard isRunning else { return }
        guard ProcessInfo.processInfo.systemUptime < deadline else { stop(); return }
        let now = ProcessInfo.processInfo.systemUptime
        if now >= nextSnapshotRead {
            refresh()
            nextSnapshotRead = now + 0.5
        }
        guard permissionGranted else { stop(); status = "权限不可用，验证已停止。"; return }
        let scanStart = ProcessInfo.processInfo.systemUptime
        let scan = reader.scan()
        let scanDuration = ProcessInfo.processInfo.systemUptime - scanStart
        if scan.state == .desktopListFound {
            scanCount += 1
            scanSeconds += scanDuration
            slowestScan = max(slowestScan, scanDuration)
        }
        if now - metricsStarted >= 2, scanCount > 0 {
            logger.notice("Geometry performance: samples=\(self.scanCount); meanMs=\(self.scanSeconds * 1000 / Double(self.scanCount)); maxMs=\(self.slowestScan * 1000)")
            metricsStarted = now
            scanCount = 0
            scanSeconds = 0
            slowestScan = 0
        }
        if scan.buttons != previousButtons {
            burstUntil = now + 0.5
            previousButtons = scan.buttons
        }
        schedule(interval: scan.state == .desktopListFound ? (now < burstUntil ? 1.0 / 60 : 0.1) : 0.2)
        if now >= nextDetailsUpdate || lastScanState != scan.state {
            details = scan.details
            nextDetailsUpdate = now + 0.25
        }
        if scan.evidenceRank > strongestEvidenceRank
            || (scan.evidenceRank == strongestEvidenceRank && scan.details.count > largestScanLength) {
            strongestEvidenceRank = scan.evidenceRank
            largestScanLength = scan.details.count
            richestScan = scan.details
            for line in scan.details.split(separator: "\n") {
                logger.notice("AX evidence: \(line, privacy: .public)")
            }
        }
        if lastScanState != scan.state {
            logger.notice("Mission Control state: \(scan.state.rawValue, privacy: .public)")
            lastScanState = scan.state
        }
        guard scan.state == .desktopListFound else {
            previousSnapshot = nil
            overlay.hide()
            lastOverlayFrame = nil
            switch scan.state {
            case .notVisible: status = "尚未读取到 Mission Control 界面；请打开调度中心并展开顶部桌面栏。"
            case .overviewFound: status = "已检测到 Mission Control 容器，但尚未读取到桌面列表；覆盖层已隐藏。"
            case .incomplete: status = "辅助功能扫描未完成或调用失败，请查看读取诊断。"
            case .desktopListFound: break
            }
            return
        }
        guard !scan.labels.isEmpty || !scan.buttons.isEmpty else {
            overlay.hide()
            lastOverlayFrame = nil
            status = "已读取桌面列表，但按钮几何不完整；覆盖层已隐藏。"
            return
        }
        // Suppress a transition frame while the persisted ordering changes.
        defer { previousSnapshot = snapshot }
        guard previousSnapshot == snapshot,
              let frame = SpaceLabelResolver.firstDesktopFrame(scan: scan, snapshot: snapshot) else {
            overlay.hide()
            lastOverlayFrame = nil
            status = "按钮布局、身份顺序或标签区域校验未通过；覆盖层已隐藏。"
            return
        }
        let shown = overlay.show(axFrame: frame)
        if shown, lastOverlayFrame != frame, now >= nextGeometryLog {
            logger.notice("Overlay geometry: AX \(String(describing: frame), privacy: .public); source=button geometry; visual verification required.")
            lastOverlayFrame = frame
            nextGeometryLog = now + 0.1
        }
        let nextStatus = shown
            ? "已提交“开发”覆盖面板；请目视确认位置与关闭后的清理。"
            : "坐标校验失败，覆盖层已隐藏。"
        if status != nextStatus { status = nextStatus }
    }
}
