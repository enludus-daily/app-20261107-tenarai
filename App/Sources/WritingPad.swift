import SwiftUI

/// 升目に指で書く。お手本は、自分の字の下に薄墨で重ねて見比べる（自動の判定はしない）
struct WritingPad: View {
    let word: Word
    @Binding var sheet: InkSheet
    let cellSize: CGFloat
    let columns: Int
    var showModel = false
    var editable = true
    var gap: CGFloat = 6

    @State var current: InkStroke?
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var count: Int { word.characters.count }
    var rows: Int { (count + columns - 1) / columns }
    var size: CGSize {
        CGSize(width: CGFloat(columns) * cellSize + CGFloat(columns - 1) * gap,
               height: CGFloat(rows) * cellSize + CGFloat(rows - 1) * gap)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(word.characters.enumerated()), id: \.offset) { index, character in
                let origin = CellLayout.origin(of: index, cellSize: cellSize, gap: gap, columns: columns)
                ZStack {
                    GridCell(highlighted: current?.cell == index)
                    if showModel {
                        Text(character)
                            .font(Typo.serif(cellSize * 0.74))
                            .foregroundStyle(Palette.usuzumi)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.04)))
                    }
                }
                .frame(width: cellSize, height: cellSize)
                .offset(x: origin.x, y: origin.y)
            }
            InkLayer(strokes: sheet.strokes + (current.map { [$0] } ?? []), cellSize: cellSize, gap: gap, columns: columns)
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(drawing, including: editable ? .all : .subviews)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("升目 \(count) マス。\(sheet.strokes.count) 画 書いた")
        .accessibilityHint(showModel ? "お手本 \(word.text) を重ねて表示中" : "指でなぞって書きます")
    }

    private var drawing: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if current == nil {
                    let cell = CellLayout.cell(at: value.startLocation, cellSize: cellSize, gap: gap, columns: columns, count: count)
                    current = InkStroke(cell: cell, points: [])
                    append(value.startLocation)
                }
                append(value.location)
            }
            .onEnded { _ in
                if let stroke = current, stroke.pointCount > 0 { sheet.strokes.append(stroke) }
                current = nil
            }
    }

    private func append(_ location: CGPoint) {
        guard var stroke = current else { return }
        let origin = CellLayout.origin(of: stroke.cell, cellSize: cellSize, gap: gap, columns: columns)
        stroke.append(CGPoint(x: location.x - origin.x, y: location.y - origin.y), cellSize: cellSize)
        current = stroke
    }
}

/// 書いた線を描く（升目ごとの座標から）
struct InkLayer: View {
    let strokes: [InkStroke]
    let cellSize: CGFloat
    var gap: CGFloat = 6
    let columns: Int
    var color: Color = Palette.ink

    var body: some View {
        Canvas { context, _ in
            let width = max(1.6, cellSize * 0.058)
            for stroke in strokes {
                let origin = CellLayout.origin(of: stroke.cell, cellSize: cellSize, gap: gap, columns: columns)
                context.stroke(
                    stroke.path(cellSize: cellSize, origin: origin),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .accessibilityHidden(true)
    }
}

/// 帖の小さな升目（自分の字か、まだ書いていなければお手本の字）
struct InkThumbnail: View {
    let word: Word
    let sheet: InkSheet?
    var cellSize: CGFloat = 34
    var hidden = false

    var body: some View {
        let columns = word.characters.count
        ZStack(alignment: .topLeading) {
            HStack(spacing: 2) {
                ForEach(Array(word.characters.enumerated()), id: \.offset) { _, character in
                    ZStack {
                        GridCell()
                        if hidden {
                            Image(systemName: "lock")
                                .font(.system(size: cellSize * 0.3))
                                .foregroundStyle(Palette.fuji)
                        } else if sheet?.isEmpty ?? true {
                            Text(character)
                                .font(Typo.serif(cellSize * 0.72))
                                .foregroundStyle(Palette.ink.opacity(0.78))
                        }
                    }
                    .frame(width: cellSize, height: cellSize)
                }
            }
            if let sheet, !sheet.isEmpty, !hidden {
                InkLayer(strokes: sheet.strokes, cellSize: cellSize, gap: 2, columns: columns)
                    .frame(width: CGFloat(columns) * cellSize + CGFloat(columns - 1) * 2, height: cellSize)
            }
        }
        .fixedSize()
    }
}
