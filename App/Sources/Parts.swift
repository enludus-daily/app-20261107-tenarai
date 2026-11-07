import SwiftUI

// 題材の現物を部品にする：習字帳の升目・半紙・文鎮・はなまる・和綴じの帖（look.md §1）

/// 升目の十字の補助線（点線）と外枠
struct CellGuide: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// 習字帳の 1 マス
struct GridCell: View {
    var highlighted = false

    var body: some View {
        ZStack {
            Rectangle().fill(Palette.paper)
            CellGuide()
                .stroke(Palette.guide, style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
            Rectangle()
                .strokeBorder(highlighted ? Palette.fuji : Palette.guide, lineWidth: highlighted ? 1.4 : 1)
        }
        .accessibilityHidden(true)
    }
}

/// 半紙の地：ごく薄い繊維の粒（固定の乱数で毎回同じ）
struct Hanshi: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x5EED
            func next() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat((seed >> 33) % 10_000) / 10_000
            }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.paper))
            for _ in 0..<Int(size.width * size.height / 900) {
                let x = next() * size.width, y = next() * size.height
                let length = 3 + next() * 7
                let angle = next() * .pi
                var fiber = Path()
                fiber.move(to: CGPoint(x: x, y: y))
                fiber.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
                context.stroke(fiber, with: .color(Palette.fuji.opacity(0.16)), lineWidth: 0.5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 文鎮：半紙の上に置いた細い棒
struct Bunchin: View {
    var body: some View {
        Capsule()
            .fill(Palette.ink.opacity(0.78))
            .frame(height: 9)
            .overlay(Capsule().fill(.white.opacity(0.18)).frame(height: 2).padding(.horizontal, 10).offset(y: -2))
            .shadow(color: Palette.ink.opacity(0.18), radius: 3, y: 2)
            .accessibilityHidden(true)
    }
}

/// はなまる：中の渦と、外の花びら
struct Hanamaru: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        // 渦（2 周。終わりが真上に来て、花びらにつながる）
        let turns: CGFloat = 2
        let steps = 90
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let angle = t * turns * 2 * .pi - .pi / 2
            let radius = r * 0.08 + r * 0.5 * t
            let p = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        // 花びら（8 枚）
        let petals = 8
        let ringR = r * 0.78
        for i in 0..<petals {
            let a0 = CGFloat(i) / CGFloat(petals) * 2 * .pi - .pi / 2
            let a1 = CGFloat(i + 1) / CGFloat(petals) * 2 * .pi - .pi / 2
            let p0 = CGPoint(x: c.x + cos(a0) * ringR, y: c.y + sin(a0) * ringR)
            let p1 = CGPoint(x: c.x + cos(a1) * ringR, y: c.y + sin(a1) * ringR)
            let mid = (a0 + a1) / 2
            let control = CGPoint(x: c.x + cos(mid) * r * 1.22, y: c.y + sin(mid) * r * 1.22)
            if i == 0 { path.addLine(to: p0) }
            path.addQuadCurve(to: p1, control: control)
        }
        return path
    }
}

/// 惜しい（△）
struct Sankaku: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.14)
        var path = Path()
        path.move(to: CGPoint(x: inset.midX, y: inset.minY))
        path.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
        path.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
        path.closeSubpath()
        return path
    }
}

/// 自分でつけた印（はなまる・△・・）
struct GradeMark: View {
    let grade: Grade
    var size: CGFloat = 28
    var progress: CGFloat = 1

    var body: some View {
        Group {
            switch grade {
            case .good:
                Hanamaru().trim(from: 0, to: progress)
                    .stroke(Palette.peachDeep, style: StrokeStyle(lineWidth: max(1.2, size * 0.06), lineCap: .round, lineJoin: .round))
            case .almost:
                Sankaku().trim(from: 0, to: progress)
                    .stroke(Palette.fujiDeep, style: StrokeStyle(lineWidth: max(1.2, size * 0.06), lineCap: .round, lineJoin: .round))
            case .miss:
                Circle().fill(Palette.sub).frame(width: size * 0.22, height: size * 0.22)
                    .opacity(progress)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(grade.label)
    }
}

/// 和綴じの帖の左端（綴じ穴と糸）
struct TojiBinding: View {
    var holes = 4

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let spacing = h / CGFloat(holes + 1)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Palette.fujiSoft)
                Path { path in
                    for i in 1...holes {
                        let y = spacing * CGFloat(i)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: 14, y: y))
                        if i < holes {
                            path.move(to: CGPoint(x: 14, y: y))
                            path.addLine(to: CGPoint(x: 14, y: y + spacing))
                        }
                    }
                }
                .stroke(Palette.thread, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                ForEach(1...holes, id: \.self) { i in
                    Circle().fill(Palette.ground)
                        .overlay(Circle().stroke(Palette.line, lineWidth: 0.6))
                        .frame(width: 5, height: 5)
                        .position(x: 14, y: spacing * CGFloat(i))
                }
            }
        }
        .frame(width: 22)
        .accessibilityHidden(true)
    }
}

/// Duo の見開きの綴じ目（左右のページの間の細い影）
struct PageGutter: View {
    var body: some View {
        LinearGradient(colors: [Palette.ink.opacity(0), Palette.ink.opacity(0.06), Palette.ink.opacity(0)], startPoint: .leading, endPoint: .trailing)
            .frame(width: 18)
            .overlay(Rectangle().fill(Palette.line).frame(width: 0.6))
            .accessibilityHidden(true)
    }
}

/// 小さなラベル（字間を開ける）
struct SmallLabel: View {
    let text: String
    var color: Color = Palette.sub

    init(_ text: String, color: Color = Palette.sub) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text).font(Typo.label).kerning(0.6).foregroundStyle(color)
    }
}

/// 白い文字を載せる主なボタン（deep）
struct InkButtonStyle: ButtonStyle {
    var filled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body).weight(.medium))
            .foregroundStyle(filled ? Color.white : Palette.fujiDeep)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(filled ? Palette.fujiDeep : Palette.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .stroke(filled ? Color.clear : Palette.line, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 例文（空欄によみを入れて、薄い藤の地で示す）
struct SentenceText: View {
    let word: Word
    var revealed = false
    var size: CGFloat = 20

    var body: some View {
        Text(attributed)
            .font(Typo.serif(size))
            .foregroundStyle(Palette.ink)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(word.sentenceParts.before + "、" + (revealed ? word.text : word.reading) + "、" + word.sentenceParts.after)
    }

    private var attributed: AttributedString {
        let parts = word.sentenceParts
        var before = AttributedString(parts.before)
        before.foregroundColor = Palette.ink
        var blank = AttributedString("\u{2009}" + (revealed ? word.text : word.reading) + "\u{2009}")
        blank.backgroundColor = Palette.fujiSoft
        blank.foregroundColor = revealed ? Palette.ink : Palette.fujiDeep
        blank.swiftUI.underlineStyle = Text.LineStyle(pattern: .solid, color: Palette.fuji)
        var after = AttributedString(parts.after)
        after.foregroundColor = Palette.ink
        return before + blank + after
    }
}
