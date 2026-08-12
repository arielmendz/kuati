// SPDX-FileCopyrightText: 2026 Ariel Mendez
// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics
import KuatiCore

private let workspace = CGRect(x: 0, y: 24, width: 1440, height: 876)

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String
) {
    guard condition() else { fatalError(message()) }
}

private func testProducesOneFramePerWindowInsideWorkspace() {
    for count in 1...12 {
        let frames = LayoutPlanner.frames(in: workspace, count: count)

        require(frames.count == count, "Expected \(count) frames, got \(frames.count)")
        for frame in frames {
            require(workspace.contains(frame), "\(frame) is outside \(workspace)")
        }
    }
}

private func testSingleWindowFillsWorkspace() {
    require(
        LayoutPlanner.frames(in: workspace, count: 1) == [workspace],
        "A single window must fill the workspace"
    )
}

private func testTwoWindowsUse95PercentOfWorkspace() {
    let frames = LayoutPlanner.frames(in: workspace, count: 2)
    let expectedSize = CGSize(
        width: floor(workspace.width * 0.95),
        height: floor(workspace.height * 0.95)
    )

    for frame in frames {
        require(frame.size == expectedSize, "Two windows must use 95% of the workspace: \(frame)")
    }
}

private func testWindowsCascadeFromUpperLeftToLowerRight() {
    let frames = LayoutPlanner.frames(in: workspace, count: 3)

    require(frames[0].origin == workspace.origin, "First window must start at the upper-left")
    require(
        frames[2].maxX == workspace.maxX && frames[2].maxY == workspace.maxY,
        "Last window must reach the lower-right"
    )
    require(
        frames[0].minX < frames[1].minX && frames[1].minX < frames[2].minX,
        "Windows must cascade horizontally"
    )
    require(
        frames[0].minY < frames[1].minY && frames[1].minY < frames[2].minY,
        "Windows must cascade vertically"
    )
    for firstIndex in frames.indices {
        for secondIndex in frames.indices where secondIndex > firstIndex {
            require(frames[firstIndex].intersects(frames[secondIndex]), "Cascade windows must overlap")
        }
    }
}

private func testThreeOrMoreWindowsUse90PercentOfWorkspace() {
    let expectedSize = CGSize(
        width: floor(workspace.width * 0.9),
        height: floor(workspace.height * 0.9)
    )

    for count in 3...20 {
        let frames = LayoutPlanner.frames(in: workspace, count: count)
        for frame in frames {
            require(
                frame.size == expectedSize,
                "\(count) windows must use 90% of the workspace: \(frame)"
            )
        }
    }
}

private func testAnimationInterpolation() {
    let start = CGRect(x: 20, y: 40, width: 600, height: 400)
    let end = CGRect(x: 100, y: 120, width: 1200, height: 800)

    require(
        FrameInterpolator.easeOut(from: start, to: end, progress: 0) == start,
        "Animation must begin at the current frame"
    )
    require(
        FrameInterpolator.easeOut(from: start, to: end, progress: 1) == end,
        "Animation must finish at the exact target frame"
    )

    let midpoint = FrameInterpolator.easeOut(from: start, to: end, progress: 0.5)
    require(midpoint.minX > 60 && midpoint.minX < end.minX, "Animation must ease toward its target")
    require(midpoint.width > 900 && midpoint.width < end.width, "Window size must animate smoothly")
}

private func testEdgeCases() {
    require(LayoutPlanner.frames(in: workspace, count: 0) == [], "Zero count failed")
    require(
        LayoutPlanner.frames(in: .zero, count: 3) == [],
        "An empty workspace must not produce frames"
    )
}

testProducesOneFramePerWindowInsideWorkspace()
testSingleWindowFillsWorkspace()
testTwoWindowsUse95PercentOfWorkspace()
testWindowsCascadeFromUpperLeftToLowerRight()
testThreeOrMoreWindowsUse90PercentOfWorkspace()
testAnimationInterpolation()
testEdgeCases()
print("All Kuati layout tests passed")
