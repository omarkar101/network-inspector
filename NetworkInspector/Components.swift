import SwiftUI
import NetworkInspectorKit

extension SourceApp {
    /// The app's stable accent color.
    var tint: Color {
        Color(hue: tintHue, saturation: 0.62, brightness: 0.88)
    }
}

/// A rounded, gradient app glyph.
struct AppIcon: View {
    let app: SourceApp
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: app.symbolName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [app.tint, app.tint.mix(with: .black, by: 0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: size * 0.28)
            )
            .shadow(color: app.tint.opacity(0.35), radius: 6, y: 3)
            .accessibilityHidden(true)
    }
}

/// A tiny filled line chart of recent activity, oldest value on the left.
struct Sparkline: View {
    let values: [Int]
    let tint: Color

    var body: some View {
        let points = values.map { Double($0) }
        ZStack {
            SparklineShape(values: points, closed: true)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.35), tint.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            SparklineShape(values: points, closed: false)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .animation(.smooth, value: values)
        .accessibilityHidden(true)
    }
}

struct SparklineShape: Shape {
    var values: [Double]
    var closed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }

        let peak = max(values.max() ?? 0, 1)
        let stepX = rect.width / CGFloat(values.count - 1)
        let points = values.enumerated().map { index, value in
            CGPoint(
                x: rect.minX + CGFloat(index) * stepX,
                y: rect.maxY - CGFloat(value / peak) * rect.height
            )
        }

        path.move(to: points[0])
        for (previous, point) in zip(points, points.dropFirst()) {
            let midX = (previous.x + point.x) / 2
            path.addCurve(
                to: point,
                control1: CGPoint(x: midX, y: previous.y),
                control2: CGPoint(x: midX, y: point.y)
            )
        }

        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

extension HTTPStatusClass {
    var tint: Color {
        switch self {
        case .informational: .blue
        case .success: .green
        case .redirection: .teal
        case .clientError: .orange
        case .serverError: .red
        case .unknown: .gray
        }
    }
}

extension HTTPMethod {
    var tint: Color {
        switch self {
        case .get: .blue
        case .post: .green
        case .put, .patch: .orange
        case .delete: .red
        case .head, .options: .gray
        }
    }
}
