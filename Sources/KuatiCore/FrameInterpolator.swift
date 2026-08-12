// SPDX-FileCopyrightText: 2026 Ariel Mendez
// SPDX-License-Identifier: GPL-3.0-only

import CoreGraphics

public enum FrameInterpolator {
    /// Returns a frame along a short ease-out transition. Values outside the
    /// animation range are clamped so the first and final frames remain exact.
    public static func easeOut(from start: CGRect, to end: CGRect, progress: CGFloat) -> CGRect {
        let clampedProgress = min(1, max(0, progress))
        let inverse = 1 - clampedProgress
        let easedProgress = 1 - inverse * inverse * inverse

        return CGRect(
            x: interpolate(start.minX, end.minX, by: easedProgress),
            y: interpolate(start.minY, end.minY, by: easedProgress),
            width: interpolate(start.width, end.width, by: easedProgress),
            height: interpolate(start.height, end.height, by: easedProgress)
        )
    }

    private static func interpolate(_ start: CGFloat, _ end: CGFloat, by progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
}
