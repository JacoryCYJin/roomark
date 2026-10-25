import AppKit
import ApplicationServices

struct MissionControlLabel {
    let text: String
    let frame: CGRect
}

struct MissionControlScan {
    enum State: String {
        case notVisible, overviewFound, desktopListFound, incomplete
    }

    let state: State
    let labels: [MissionControlLabel]
    let buttons: [MissionControlDesktopButton]
    let desktopButtonCount: Int
    let details: String
    let evidenceRank: Int
}

/// macOS 26+ hosts the Spaces AX tree in WindowManager; older releases use Dock.
/// Returns raw button geometry separately from derived label bands.
@MainActor
final class MissionControlAccessibilityReader {
    private struct CachedList {
        let element: AXUIElement
        let displayFrame: CGRect
        let host: MissionControlDesktopButton.Host
    }
    private var cachedList: CachedList?

    func reset() { cachedList = nil }

    private struct Visit {
        let element: AXUIElement
        let depth: Int
        let inOverview: Bool
        let inDesktopList: Bool
        let desktopTitle: String?
        let isTitleElement: Bool
        let barFrame: CGRect?
        let displayFrame: CGRect?
    }

    func scan() -> MissionControlScan {
        if let cachedList { return scanGeometry(cachedList) }
        var reports: [String] = []
        var labels: [MissionControlLabel] = []
        var buttons: [MissionControlDesktopButton] = []
        var hasOverview = false
        var hasDesktopList = false
        var incomplete = false
        var buttonCount = 0
        var totalNodes = 0
        let bundles = ["com.apple.WindowManager", "com.apple.dock"]
        let attributes = [kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute,
                          kAXValueAttribute, kAXIdentifierAttribute, kAXPositionAttribute,
                          kAXSizeAttribute, kAXChildrenAttribute, kAXWindowsAttribute,
                          "AXChildrenInNavigationOrder", "AXFrame", kAXTitleUIElementAttribute] as CFArray

        for bundle in bundles {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
                reports.append("\(bundle)：进程未运行")
                continue
            }
            let root = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(root, 0.06)
            var queue = [Visit(element: root, depth: 0, inOverview: false,
                               inDesktopList: false, desktopTitle: nil, isTitleElement: false,
                               barFrame: nil, displayFrame: nil)]
            var visited: [AXUIElement] = []
            var errors = Set<Int32>()
            var samples: [String] = []
            var index = 0
            let deadline = ProcessInfo.processInfo.systemUptime + 0.16
            while index < queue.count, index < 600, ProcessInfo.processInfo.systemUptime < deadline {
                let visit = queue[index]
                index += 1
                guard !visited.contains(where: { CFEqual($0, visit.element) }) else { continue }
                visited.append(visit.element)
                var result: CFArray?
                let error = AXUIElementCopyMultipleAttributeValues(visit.element, attributes, [], &result)
                guard error == .success, let values = result as? [Any], values.count == 12 else {
                    errors.insert(error.rawValue)
                    continue
                }
                let role = values[0] as? String ?? ""
                let identifier = values[4] as? String ?? ""
                let text = Self.nonemptyText(values[1...3].compactMap { $0 as? String })
                let overview = visit.inOverview || identifier == "mc" || identifier == "mc.display"
                let inList = visit.inDesktopList || (overview && identifier == "mc.spaces.list")
                hasOverview = hasOverview || overview
                hasDesktopList = hasDesktopList || (overview && identifier == "mc.spaces.list")
                let isDesktop = inList && role == kAXButtonRole && text.flatMap(SpaceLabelResolver.ordinal(in:)) != nil
                let desktopTitle = isDesktop ? text : visit.desktopTitle
                if isDesktop { buttonCount += 1 }
                let position = point(values[5])
                let size = size(values[6])
                let axFrame = rect(values[10])
                let positionedFrame = position.flatMap { origin in size.map { CGRect(origin: origin, size: $0) } }
                let frame = axFrame ?? positionedFrame
                let displayFrame = identifier == "mc.display" ? frame : visit.displayFrame
                let barFrame = identifier == "mc.spaces" || identifier == "mc.spaces.list" ? frame : visit.barFrame
                if overview, identifier == "mc.spaces.list", let displayFrame,
                   bundle == "com.apple.WindowManager" {
                    cachedList = CachedList(element: visit.element, displayFrame: displayFrame, host: .windowManager)
                }
                if isDesktop, let text, let position, let size, let barFrame, let displayFrame {
                    buttons.append(MissionControlDesktopButton(title: text, position: position, size: size,
                                                               barFrame: barFrame, displayFrame: displayFrame,
                                                               host: bundle == "com.apple.WindowManager" ? .windowManager : .dock))
                }
                let isText = role == kAXStaticTextRole || visit.isTitleElement
                if inList, let labelText = text.flatMap({ SpaceLabelResolver.ordinal(in: $0) != nil ? $0 : nil }) ?? desktopTitle,
                   (isText || isDesktop),
                   let frame = Self.labelFrame(role: role, isTitleElement: visit.isTitleElement,
                                               axFrame: axFrame, positionAndSize: positionedFrame) {
                    if !labels.contains(where: { $0.text == labelText && $0.frame == frame }) {
                        labels.append(MissionControlLabel(text: labelText, frame: frame))
                    }
                }

                // Only desktop labels are logged; unrelated window titles are omitted.
                if samples.count < 100, identifier.hasPrefix("mc") || inList {
                    samples.append("depth=\(visit.depth) \(role) [\(identifier)] desktop=\(isDesktop ? text ?? "" : "") AXFrame=\(axFrame.map(String.init(describing:)) ?? "nil") position=\(position.map(String.init(describing:)) ?? "nil") size=\(size.map(String.init(describing:)) ?? "nil") titleElement=\(visit.isTitleElement)")
                    if isDesktop {
                        samples.append(contentsOf: geometryAttributes(of: visit.element))
                    }
                }
                guard visit.depth < 14 else { incomplete = true; continue }
                // Prioritize Mission Control containers, avoiding unrelated window subtrees.
                if !overview, visit.depth > 0, !identifier.hasPrefix("mc") { continue }
                var children: [AXUIElement] = []
                for value in values[7...9] {
                    if let elements = value as? [AXUIElement] { children.append(contentsOf: elements) }
                }
                queue.append(contentsOf: children.map {
                    Visit(element: $0, depth: visit.depth + 1, inOverview: overview,
                          inDesktopList: inList, desktopTitle: desktopTitle, isTitleElement: false,
                          barFrame: barFrame, displayFrame: displayFrame)
                })
                if CFGetTypeID(values[11] as CFTypeRef) == AXUIElementGetTypeID() {
                    queue.append(Visit(element: values[11] as! AXUIElement, depth: visit.depth + 1,
                                       inOverview: overview, inDesktopList: inList,
                                       desktopTitle: desktopTitle, isTitleElement: true,
                                       barFrame: barFrame, displayFrame: displayFrame))
                }
            }
            let capped = index < queue.count
            incomplete = incomplete || capped || !errors.isEmpty
            totalNodes += visited.count
            reports.append("\(bundle) pid=\(app.processIdentifier)：节点 \(visited.count)，错误 \(errors.sorted())，扫描截断 \(capped)\n\(samples.joined(separator: "\n"))")
            // A populated modern tree takes precedence over the legacy empty stub.
            if hasDesktopList { break }
        }
        let state: MissionControlScan.State = incomplete ? .incomplete : hasDesktopList ? .desktopListFound
            : hasOverview ? .overviewFound : incomplete ? .incomplete : .notVisible
        if state != .desktopListFound { cachedList = nil }
        let summary = "状态 \(state.rawValue)；节点 \(totalNodes)；桌面按钮 \(buttonCount)；完整按钮几何 \(buttons.count)；独立标签坐标 \(labels.count)"
        return MissionControlScan(state: state, labels: labels, buttons: buttons, desktopButtonCount: buttonCount,
                                  details: summary + "\n" + reports.joined(separator: "\n"),
                                  evidenceRank: (hasDesktopList ? 10000 : hasOverview ? 1000 : 0) + buttonCount * 10 + labels.count)
    }

    /// The hot path reads the existing list and one batch per button. Attribute
    /// enumeration, diagnostic tree walks and parent lookup happen on discovery.
    private func scanGeometry(_ cache: CachedList) -> MissionControlScan {
        let start = ProcessInfo.processInfo.systemUptime
        func unavailable(_ state: MissionControlScan.State) -> MissionControlScan {
            cachedList = nil
            return MissionControlScan(state: state, labels: [], buttons: [], desktopButtonCount: 0,
                                      details: "缓存的桌面列表已失效；下轮重新发现。", evidenceRank: 0)
        }
        let listAttributes = [kAXPositionAttribute, kAXSizeAttribute, kAXChildrenAttribute] as CFArray
        AXUIElementSetMessagingTimeout(cache.element, 0.02)
        var listResult: CFArray?
        let listError = AXUIElementCopyMultipleAttributeValues(cache.element, listAttributes, [], &listResult)
        guard listError == .success, let values = listResult as? [Any], values.count == 3,
              let position = point(values[0]), let size = size(values[1]),
              let children = values[2] as? [AXUIElement], !children.isEmpty else {
            return unavailable(listError == .invalidUIElement ? .notVisible : .incomplete)
        }
        let barFrame = CGRect(origin: position, size: size)
        let buttonAttributes = [kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute,
                                kAXPositionAttribute, kAXSizeAttribute] as CFArray
        var buttons: [MissionControlDesktopButton] = []
        for child in children {
            // Keep a slow/busy host from building a backlog of display ticks.
            guard ProcessInfo.processInfo.systemUptime - start < 0.04 else { return unavailable(.incomplete) }
            AXUIElementSetMessagingTimeout(child, 0.02)
            var result: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(child, buttonAttributes, [], &result) == .success,
                  let data = result as? [Any], data.count == 5 else { return unavailable(.incomplete) }
            guard data[0] as? String == kAXButtonRole,
                  let title = Self.nonemptyText(data[1...2].compactMap { $0 as? String }),
                  SpaceLabelResolver.ordinal(in: title) != nil else { continue }
            guard let anchor = point(data[3]), let buttonSize = self.size(data[4]) else { return unavailable(.incomplete) }
            buttons.append(MissionControlDesktopButton(title: title, position: anchor, size: buttonSize,
                barFrame: barFrame, displayFrame: cache.displayFrame, host: cache.host))
        }
        guard !buttons.isEmpty else { return unavailable(.notVisible) }
        let duration = (ProcessInfo.processInfo.systemUptime - start) * 1000
        let details = "缓存几何读取：\(buttons.count) 个普通桌面，\(String(format: "%.2f", duration)) ms；栏 \(barFrame)"
        return MissionControlScan(state: .desktopListFound, labels: [], buttons: buttons,
            desktopButtonCount: buttons.count, details: details, evidenceRank: 10000 + buttons.count * 10)
    }

    nonisolated static func nonemptyText(_ strings: [String]) -> String? {
        strings.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
    }

    private func geometryAttributes(of element: AXUIElement) -> [String] {
        var names: CFArray?
        var parameters: CFArray?
        let namesError = AXUIElementCopyAttributeNames(element, &names)
        let parametersError = AXUIElementCopyParameterizedAttributeNames(element, &parameters)
        let attributes = names as? [String] ?? []
        var result = ["desktop attributes=\(attributes.sorted()) error=\(namesError.rawValue)",
                      "desktop parameterized=\((parameters as? [String] ?? []).sorted()) error=\(parametersError.rawValue)"]
        for name in attributes where ["Title", "Frame", "Bounds", "Text", "Position", "Size", "Children"].contains(where: name.contains) {
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
            guard let value else { result.append("\(name)=nil error=\(error.rawValue)"); continue }
            if CFGetTypeID(value) == CFArrayGetTypeID() {
                result.append("\(name)=array count \(CFArrayGetCount((value as! CFArray)))")
            } else if CFGetTypeID(value) == AXUIElementGetTypeID() {
                result.append("\(name)=AXUIElement")
            } else {
                result.append("\(name)=\(String(describing: value)) error=\(error.rawValue)")
            }
        }
        return result
    }

    nonisolated static func labelFrame(role: String, isTitleElement: Bool,
                                      axFrame: CGRect?, positionAndSize: CGRect?) -> CGRect? {
        guard role == "AXStaticText" || role == "AXButton" || isTitleElement else { return nil }
        // An expanded thumbnail is never a label. No inferred baseline or offset.
        return [axFrame, positionAndSize].compactMap { $0 }.first {
            $0.minX.isFinite && $0.minY.isFinite && $0.width.isFinite && $0.height.isFinite
                && $0.width >= 24 && $0.height > 0 && $0.height <= 40
        }
    }

    private func point(_ raw: Any) -> CGPoint? {
        guard CFGetTypeID(raw as CFTypeRef) == AXValueGetTypeID() else { return nil }
        let value = raw as! AXValue
        guard AXValueGetType(value) == .cgPoint else { return nil }
        var output = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &output) ? output : nil
    }

    private func size(_ raw: Any) -> CGSize? {
        guard CFGetTypeID(raw as CFTypeRef) == AXValueGetTypeID() else { return nil }
        let value = raw as! AXValue
        guard AXValueGetType(value) == .cgSize else { return nil }
        var output = CGSize.zero
        return AXValueGetValue(value, .cgSize, &output) ? output : nil
    }

    private func rect(_ raw: Any) -> CGRect? {
        guard CFGetTypeID(raw as CFTypeRef) == AXValueGetTypeID() else { return nil }
        let value = raw as! AXValue
        guard AXValueGetType(value) == .cgRect else { return nil }
        var output = CGRect.zero
        return AXValueGetValue(value, .cgRect, &output) ? output : nil
    }
}
