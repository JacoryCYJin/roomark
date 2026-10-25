import Foundation

enum ScreenCoordinateConverter {
    /// AX has a top-left origin at the primary display; AppKit has bottom-left.
    static func appKitRect(fromAX rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY,
               width: rect.width, height: rect.height)
    }
}
