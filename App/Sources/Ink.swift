import SwiftUI

/// 指で書いた 1 画。座標は升目 1 つを 0〜1000 とした整数（升目の大きさが変わっても同じ形に描ける）
struct InkStroke: Codable, Equatable, Sendable {
    /// どの升目に書き始めたか
    var cell: Int
    /// x, y, x, y, … の並び
    var points: [Int16]

    static let scale: CGFloat = 1000

    var pointCount: Int { points.count / 2 }

    mutating func append(_ point: CGPoint, cellSize: CGFloat) {
        let x = Int16(clamping: Int((point.x * Self.scale / cellSize).rounded()))
        let y = Int16(clamping: Int((point.y * Self.scale / cellSize).rounded()))
        // 同じ点が続いたら足さない（記録を軽くする）
        if points.count >= 2, points[points.count - 2] == x, points[points.count - 1] == y { return }
        points.append(x)
        points.append(y)
    }

    func cgPoints(cellSize: CGFloat) -> [CGPoint] {
        stride(from: 0, to: points.count - 1, by: 2).map { i in
            CGPoint(x: CGFloat(points[i]) * cellSize / Self.scale, y: CGFloat(points[i + 1]) * cellSize / Self.scale)
        }
    }

    /// 点をなめらかにつないだ線（中点を通る 2 次曲線）
    func path(cellSize: CGFloat, origin: CGPoint = .zero) -> Path {
        let pts = cgPoints(cellSize: cellSize).map { CGPoint(x: $0.x + origin.x, y: $0.y + origin.y) }
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        if pts.count == 1 {
            path.addLine(to: CGPoint(x: first.x + 0.5, y: first.y + 0.5))
            return path
        }
        for i in 1..<pts.count {
            let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
            path.addQuadCurve(to: mid, control: pts[i - 1])
        }
        path.addLine(to: pts[pts.count - 1])
        return path
    }
}

/// 1 語ぶんの書いた字
struct InkSheet: Codable, Equatable, Sendable {
    var strokes: [InkStroke] = []
    var day: Day?

    var isEmpty: Bool { strokes.isEmpty }

    func strokes(inCell cell: Int) -> [InkStroke] { strokes.filter { $0.cell == cell } }

    mutating func undo() { if !strokes.isEmpty { strokes.removeLast() } }
}

/// 升目の並び（何列で並べるか）。書いた字は升目ごとに持つので、並びが変わっても崩れない
enum CellLayout {
    static func columns(count: Int, isWide: Bool) -> Int {
        if isWide || count <= 2 { return max(count, 1) }
        return 2
    }

    /// 点がどの升目の上か（升目の外なら一番近い升目）
    static func cell(at point: CGPoint, cellSize: CGFloat, gap: CGFloat, columns: Int, count: Int) -> Int {
        let pitch = cellSize + gap
        let col = min(max(Int(point.x / pitch), 0), columns - 1)
        let row = max(Int(point.y / pitch), 0)
        return min(row * columns + col, count - 1)
    }

    static func origin(of cell: Int, cellSize: CGFloat, gap: CGFloat, columns: Int) -> CGPoint {
        CGPoint(x: CGFloat(cell % columns) * (cellSize + gap), y: CGFloat(cell / columns) * (cellSize + gap))
    }
}
