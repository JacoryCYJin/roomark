import Foundation

@MainActor
protocol SpaceProvider {
    func readSnapshot() throws -> SpaceSnapshot
}

enum SpaceReadError: LocalizedError {
    case missingConfiguration
    case invalidIdentity

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "系统未提供可识别的 Spaces 配置。"
        case .invalidIdentity: "桌面身份缺失或重复，停止映射以避免名称错配。"
        }
    }
}
