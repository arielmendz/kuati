// SPDX-FileCopyrightText: 2026 Ariel Mendez
// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

public enum LayoutPlanner {
    private static let twoWindowScale: CGFloat = 0.95
    private static let multiWindowScale: CGFloat = 0.9

    /// Maximizes a single window. With multiple windows, produces equal-size
    /// frames that cascade diagonally across `workspace`. Two windows use 95%
    /// of the usable maximized size; three or more use 90%.
    public static func frames(in workspace: CGRect, count: Int) -> [CGRect] {
        guard count > 0, workspace.width > 0, workspace.height > 0 else { return [] }
        guard count > 1 else { return [workspace] }

        let windowScale = count == 2 ? twoWindowScale : multiWindowScale
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
            let progress = CGFloat(index) / divisor
            return CGRect(
                x: round(workspace.minX + cascadeRange.width * progress),
                y: round(workspace.minY + cascadeRange.height * progress),
                width: windowSize.width,
                height: windowSize.height
            )
        }
    }
}
