//
//  ArtworkColorExtractor.swift
//  FlowIsland
//

import AppKit

// 后台任务只把可跨线程传递的数值交回 View，不传递 AppKit 引用类型。
struct ArtworkAccentColor: Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    static let white = ArtworkAccentColor(
        red: 1,
        green: 1,
        blue: 1,
        opacity: 1
    )
}

// 图像处理与 View 分离，避免布局代码同时承担像素读取职责。
enum ArtworkColorExtractor {
    static func accentColor(from artworkData: Data?) -> ArtworkAccentColor {
        guard
            let artworkData,
            let image = NSImage(data: artworkData),
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 1,
                pixelsHigh: 1,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 4,
                bitsPerPixel: 32
            ),
            let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            return .white
        }

        NSGraphicsContext.saveGraphicsState()
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: 1, height: 1),
            from: .zero,
            operation: .copy,
            fraction: 1
        )

        guard
            let averageColor = bitmap.colorAt(x: 0, y: 0),
            let rgbColor = averageColor.usingColorSpace(.sRGB)
        else {
            return .white
        }

        return components(
            from: visibleAccentColor(from: rgbColor)
        )
    }

    private static func visibleAccentColor(from color: NSColor) -> NSColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        color.getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        )

        // 近灰色封面不强行染成某个色相。
        guard saturation >= 0.08 else {
            return .white
        }

        let saturatedColor = NSColor(
            calibratedHue: hue,
            saturation: max(saturation, 0.5),
            brightness: max(brightness, 0.65),
            alpha: 1
        )

        return colorMeetingTextContrast(
            saturatedColor,
            againstBlack: 4.5
        )
    }

    private static func colorMeetingTextContrast(
        _ color: NSColor,
        againstBlack minimumContrast: CGFloat
    ) -> NSColor {
        guard let rgbColor = color.usingColorSpace(.sRGB) else {
            return .white
        }

        if contrastAgainstBlack(of: rgbColor) >= minimumContrast {
            return rgbColor
        }

        let red = rgbColor.redComponent
        let green = rgbColor.greenComponent
        let blue = rgbColor.blueComponent
        var lowerFraction: CGFloat = 0
        var upperFraction: CGFloat = 1

        // 二分查找只加入满足可读性所需的最少白色，尽量保留封面色相。
        for _ in 0..<12 {
            let fraction = (lowerFraction + upperFraction) / 2
            let candidate = colorBlendedTowardWhite(
                red: red,
                green: green,
                blue: blue,
                fraction: fraction
            )

            if contrastAgainstBlack(of: candidate) >= minimumContrast {
                upperFraction = fraction
            } else {
                lowerFraction = fraction
            }
        }

        return colorBlendedTowardWhite(
            red: red,
            green: green,
            blue: blue,
            fraction: upperFraction
        )
    }

    private static func colorBlendedTowardWhite(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        fraction: CGFloat
    ) -> NSColor {
        NSColor(
            srgbRed: red + (1 - red) * fraction,
            green: green + (1 - green) * fraction,
            blue: blue + (1 - blue) * fraction,
            alpha: 1
        )
    }

    private static func contrastAgainstBlack(of color: NSColor) -> CGFloat {
        let luminance = 0.2126 * linearized(color.redComponent)
            + 0.7152 * linearized(color.greenComponent)
            + 0.0722 * linearized(color.blueComponent)

        return (luminance + 0.05) / 0.05
    }

    private static func linearized(_ component: CGFloat) -> CGFloat {
        if component <= 0.04045 {
            return component / 12.92
        }

        return CGFloat(
            pow(
                Double((component + 0.055) / 1.055),
                2.4
            )
        )
    }

    private static func components(
        from color: NSColor
    ) -> ArtworkAccentColor {
        guard let rgbColor = color.usingColorSpace(.sRGB) else {
            return .white
        }

        return ArtworkAccentColor(
            red: Double(rgbColor.redComponent),
            green: Double(rgbColor.greenComponent),
            blue: Double(rgbColor.blueComponent),
            opacity: Double(rgbColor.alphaComponent)
        )
    }
}
