import CoreGraphics

public enum LayoutPlanner {
    public static let windowScale: CGFloat = 0.9

    /// Produces equal-size frames that cascade diagonally across `workspace`.
    /// Every frame is 90% of the usable maximized size. The first frame starts
    /// at the upper-left and the last reaches the lower-right.
    public static func frames(in workspace: CGRect, count: Int) -> [CGRect] {
        guard count > 0, workspace.width > 0, workspace.height > 0 else { return [] }

        let windowSize = CGSize(
            width: floor(workspace.width * windowScale),
            height: floor(workspace.height * windowScale)
        )
        let cascadeRange = CGSize(
            width: workspace.width - windowSize.width,
            height: workspace.height - windowSize.height
        )
        let divisor = CGFloat(max(1, count - 1))

        return (0..<count).map { index in
            let progress = count == 1 ? 0 : CGFloat(index) / divisor
            return CGRect(
                x: round(workspace.minX + cascadeRange.width * progress),
                y: round(workspace.minY + cascadeRange.height * progress),
                width: windowSize.width,
                height: windowSize.height
            )
        }
    }
}
