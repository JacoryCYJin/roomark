import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var monitor: MissionControlMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Roomark").font(.largeTitle.bold())
            Text("Mission Control 核心能力验证").font(.title3).foregroundStyle(.secondary)
            Text("先刷新桌面并授权，再开始验证。打开 Mission Control，检查首个普通桌面的名称位置是否出现“开发”。")
            HStack {
                Label(monitor.permissionGranted ? "已获辅助功能权限" : "需要辅助功能权限",
                      systemImage: monitor.permissionGranted ? "checkmark.shield" : "lock.shield")
                Spacer()
                Button("请求授权") { AccessibilityPermission.request(); monitor.refresh() }
                Button("打开权限设置") { AccessibilityPermission.openSettings() }
            }
            HStack {
                Button("刷新桌面") { monitor.refresh() }
                Button(monitor.isRunning ? "重新开始 90 秒验证" : "开始 90 秒验证") { monitor.start() }
                    .buttonStyle(.borderedProminent)
                Button("停止并隐藏") { monitor.stop() }.disabled(!monitor.isRunning)
            }
            Text(monitor.status).font(.callout).textSelection(.enabled)
            Text("配置快照：\(monitor.snapshot.desktops.count) 个普通桌面，\(monitor.snapshot.otherSpaceCount) 个其他 Space")
                .font(.headline)
            List(monitor.snapshot.desktops) { desktop in
                VStack(alignment: .leading, spacing: 4) {
                    Text("桌面 \(desktop.ordinal) · \(desktop.identity.displayID)")
                    Text(desktop.identity.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                }.textSelection(.enabled)
            }
            DisclosureGroup("读取诊断") {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("当前扫描\n" + monitor.details)
                        Divider()
                        Text("本轮信息最多的扫描（退出 Mission Control 后保留）\n" + monitor.richestScan)
                    }
                    .font(.caption.monospaced()).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
            }
            Text("按钮几何验证版。使用 WindowManager 的真实锚点、尺寸和桌面栏边界计算标签区域，仍需目视验收。暂不保存名称，多显示组映射尚未实现。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 650, minHeight: 500)
        .onAppear { monitor.refresh() }
        .onDisappear { monitor.stop() }
    }
}
