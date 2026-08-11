import CoreGraphics

public enum LayoutPlanner {
    /// Produces a balanced grid that fills `workspace`. The final row is allowed
    /// to contain fewer windows and is expanded to use the available width.
    public static func frames(in workspace: CGRect, count: Int, gap: CGFloat) -> [CGRect] {
        guard count > 0, workspace.width > 0, workspace.height > 0 else { return [] }

        let safeGap = max(0, gap)
        let aspectRatio = workspace.width / workspace.height
        let preferredWindowAspect: CGFloat = 1.25
        let columns = min(
            count,
            max(1, Int(ceil(sqrt(CGFloat(count) * aspectRatio / preferredWindowAspect))))
        )
        let rows = Int(ceil(CGFloat(count) / CGFloat(columns)))

        let availableHeight = max(0, workspace.height - safeGap * CGFloat(rows + 1))
        let rowHeight = availableHeight / CGFloat(rows)
        let baseCount = count / rows
        let rowsWithExtraWindow = count % rows

        var result: [CGRect] = []
        for row in 0..<rows {
            let windowsInRow = baseCount + (row < rowsWithExtraWindow ? 1 : 0)
            let availableWidth = max(
                0,
                workspace.width - safeGap * CGFloat(windowsInRow + 1)
            )
            let columnWidth = availableWidth / CGFloat(windowsInRow)

            for column in 0..<windowsInRow {
                result.append(
                    CGRect(
                        x: workspace.minX + safeGap + CGFloat(column) * (columnWidth + safeGap),
                        y: workspace.minY + safeGap + CGFloat(row) * (rowHeight + safeGap),
                        width: columnWidth,
                        height: rowHeight
                    ).integral
                )
            }
        }

        return result
    }
}
