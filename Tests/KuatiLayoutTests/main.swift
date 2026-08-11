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
        let frames = LayoutPlanner.frames(in: workspace, count: count, gap: 10)

        require(frames.count == count, "Expected \(count) frames, got \(frames.count)")
        for frame in frames {
            require(workspace.contains(frame), "\(frame) is outside \(workspace)")
            require(frame.width > 0, "Frame has no width: \(frame)")
            require(frame.height > 0, "Frame has no height: \(frame)")
        }
    }
}

private func testFramesDoNotOverlap() {
    let frames = LayoutPlanner.frames(in: workspace, count: 9, gap: 12)

    for firstIndex in frames.indices {
        for secondIndex in frames.indices where secondIndex > firstIndex {
            require(
                !frames[firstIndex].intersects(frames[secondIndex]),
                "Frames overlap: \(frames[firstIndex]) and \(frames[secondIndex])"
            )
        }
    }
}

private func testMoreWindowsYieldSmallerAverageFrames() {
    var previousAverageArea = CGFloat.greatestFiniteMagnitude

    for count in 1...10 {
        let frames = LayoutPlanner.frames(in: workspace, count: count, gap: 8)
        let averageArea = frames.map { $0.width * $0.height }.reduce(0, +) / CGFloat(count)
        require(
            averageArea < previousAverageArea,
            "Average area did not shrink at \(count) windows"
        )
        previousAverageArea = averageArea
    }
}

private func testEdgeCases() {
    require(LayoutPlanner.frames(in: workspace, count: 0, gap: 10) == [], "Zero count failed")

    let negativeGap = LayoutPlanner.frames(in: workspace, count: 4, gap: -10)
    let zeroGap = LayoutPlanner.frames(in: workspace, count: 4, gap: 0)
    require(negativeGap == zeroGap, "A negative gap must be treated as zero")
}

testProducesOneFramePerWindowInsideWorkspace()
testFramesDoNotOverlap()
testMoreWindowsYieldSmallerAverageFrames()
testEdgeCases()
print("All Kuati layout tests passed")
