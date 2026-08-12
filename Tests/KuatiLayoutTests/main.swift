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
            require(
                frame.width == floor(workspace.width * 0.9),
                "Frame is not 90% of the workspace width: \(frame)"
            )
            require(
                frame.height == floor(workspace.height * 0.9),
                "Frame is not 90% of the workspace height: \(frame)"
            )
        }
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

private func testEveryWindowKeepsTheSameSizeAsCountGrows() {
    let reference = LayoutPlanner.frames(in: workspace, count: 1)[0].size

    for count in 2...20 {
        let frames = LayoutPlanner.frames(in: workspace, count: count)
        for frame in frames {
            require(
                frame.size == reference,
                "Window size changed when the cascade grew to \(count) windows"
            )
        }
    }
}

private func testEdgeCases() {
    require(LayoutPlanner.frames(in: workspace, count: 0) == [], "Zero count failed")
    require(
        LayoutPlanner.frames(in: .zero, count: 3) == [],
        "An empty workspace must not produce frames"
    )
}

testProducesOneFramePerWindowInsideWorkspace()
testWindowsCascadeFromUpperLeftToLowerRight()
testEveryWindowKeepsTheSameSizeAsCountGrows()
testEdgeCases()
print("All Kuati layout tests passed")
