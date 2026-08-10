//
//  NotchShape.swift
//  FlowIsland
//
//  Created by Awstme on 2026/8/9.
//

import SwiftUI

struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    // 同时插值两个圆角，展开和收起时轮廓才能连续过渡。
    var animatableData:
        AnimatablePair<CGFloat, CGFloat> {
        get {
            AnimatablePair(
                topCornerRadius,
                bottomCornerRadius
            )
        }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let leftEdge =
            rect.minX + topCornerRadius

        let rightEdge =
            rect.maxX - topCornerRadius

        // SwiftUI 的局部坐标从左上角开始，因此顶部是 minY。
        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        // 左上角从 rect 边缘弯入岛体。
        path.addQuadCurve(
            to: CGPoint(
                x: leftEdge,
                y: rect.minY + topCornerRadius
            ),
            control: CGPoint(
                x: leftEdge,
                y: rect.minY
            )
        )

        // 左侧边。
        path.addLine(
            to: CGPoint(
                x: leftEdge,
                y: rect.maxY - bottomCornerRadius
            )
        )

        // 左下圆角。
        path.addQuadCurve(
            to: CGPoint(
                x: leftEdge + bottomCornerRadius,
                y: rect.maxY
            ),
            control: CGPoint(
                x: leftEdge,
                y: rect.maxY
            )
        )

        // 岛体底边。
        path.addLine(
            to: CGPoint(
                x: rightEdge - bottomCornerRadius,
                y: rect.maxY
            )
        )

        // 右下圆角。
        path.addQuadCurve(
            to: CGPoint(
                x: rightEdge,
                y: rect.maxY - bottomCornerRadius
            ),
            control: CGPoint(
                x: rightEdge,
                y: rect.maxY
            )
        )

        // 右侧边。
        path.addLine(
            to: CGPoint(
                x: rightEdge,
                y: rect.minY + topCornerRadius
            )
        )

        // 右上角重新连接 rect 边缘。
        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX,
                y: rect.minY
            ),
            control: CGPoint(
                x: rightEdge,
                y: rect.minY
            )
        )

        path.closeSubpath()
        return path
    }
}

#Preview {
    NotchShape(
        topCornerRadius: 6,
        bottomCornerRadius: 14
    )
    .fill(.black)
    .frame(width: 200, height: 80)
    .padding()
}
