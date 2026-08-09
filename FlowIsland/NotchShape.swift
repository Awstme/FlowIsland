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

    // 告诉 SwiftUI 这两个数字可以参与动画。
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

        // 从屏幕顶部左侧开始。
        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        // 左上角：从屏幕边缘弯入刘海主体。
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

        // 左边向下。
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

        // 刘海底边。
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

        // 右边向上。
        path.addLine(
            to: CGPoint(
                x: rightEdge,
                y: rect.minY + topCornerRadius
            )
        )

        // 右上角：重新连接屏幕边缘。
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
