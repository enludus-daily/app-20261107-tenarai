import SwiftUI

/// 今日の稽古：表紙 → 稽古（書く → 見比べる → 丸をつける）→ 今日の一枚
struct TodayView: View {
    @Environment(AppModel.self) var model
    @State var started = false

    var body: some View {
        let plan = model.todayPlan
        ZStack {
            Palette.ground.ignoresSafeArea()
            if plan.isDone {
                DoneView()
                    .transition(.opacity)
            } else if plan.wordIDs.isEmpty {
                NothingTodayView()
            } else if started || plan.position > 0 || ["practice", "answer"].contains(model.screenshotScene ?? "") {
                PracticeSession()
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
                TodayCover { withAnimation(.easeOut(duration: 0.3)) { started = true } }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: plan.isDone)
        .onAppear { model.ensureTodayPlan() }
    }
}

// MARK: - 表紙

struct TodayCover: View {
    @Environment(AppModel.self) var model
    @Environment(\.horizontalSizeClass) var sizeClass
    let start: () -> Void

    var body: some View {
        let plan = model.todayPlan
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header
                ZStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Space.l) {
                        SmallLabel("今日の稽古")
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(plan.wordIDs.count)")
                                .font(Typo.serif(64))
                                .kerning(-3)
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                            Text("字").font(Typo.serif(20)).foregroundStyle(Palette.sub)
                        }
                        HStack(spacing: Space.s) {
                            tag("戻ってきた字 \(plan.reviewCount)", filled: true)
                            tag("はじめての字 \(plan.newCount)", filled: false)
                        }
                        readings(plan)
                        Button("稽古を始める", action: start)
                            .buttonStyle(InkButtonStyle())
                            .padding(.top, Space.s)
                    }
                    .padding(Space.xl)
                    .padding(.top, Space.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Hanshi().clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous)))
                    .overlay(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).stroke(Palette.line, lineWidth: 0.6))
                    .softShadow()
                    Bunchin().frame(width: 120).offset(y: -4)
                }
                StatsStrip()
                Text("升目に指で書いて、お手本を重ねて見比べます。丸は自分でつけます。書けなかった字は明日、書けた字は 3・7・14 日あけて戻ってきます。")
                    .font(Typo.small)
                    .foregroundStyle(Palette.sub)
                    .lineSpacing(4)
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.l)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.today.japaneseShort)
                .font(Typo.serif(30))
                .kerning(-1)
                .foregroundStyle(Palette.ink)
            Text(greeting).font(Typo.body).foregroundStyle(Palette.sub)
        }
    }

    private var greeting: String {
        if model.totalDays == 0 { return "はじめまして。まずは 1 字から。" }
        if model.streak == 0 { return "おかえりなさい。これまでに \(model.totalDays) 日、稽古しました。" }
        return "\(model.streak) 日続いています。"
    }

    private func tag(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(Typo.label)
            .kerning(0.4)
            .foregroundStyle(filled ? Palette.fujiDeep : Palette.sub)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(filled ? Palette.fujiSoft : Palette.paper))
            .overlay(Capsule().stroke(Palette.line, lineWidth: filled ? 0 : 0.6))
    }

    /// これから書く字の「よみ」だけを並べる（字は見せない）
    private func readings(_ plan: DayPlan) -> some View {
        FlowRow(spacing: 6) {
            ForEach(plan.wordIDs.prefix(12), id: \.self) { id in
                Text(WordBook.word(id)?.reading ?? "")
                    .font(Typo.serif(13))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous).stroke(Palette.guide, style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日書く字のよみ")
    }
}

/// 続けた日・合計・書ける字
struct StatsStrip: View {
    @Environment(AppModel.self) var model

    var body: some View {
        HStack(spacing: 0) {
            stat("\(model.streak)", "続けた日")
            Rectangle().fill(Palette.line).frame(width: 0.6, height: 34)
            stat("\(model.totalDays)", "稽古した日")
            Rectangle().fill(Palette.line).frame(width: 0.6, height: 34)
            stat("\(model.masteredCount)", "書ける字")
        }
        .padding(.vertical, Space.m)
        .background(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).stroke(Palette.line, lineWidth: 0.6))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Typo.serif(26)).kerning(-1).monospacedDigit()
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            SmallLabel(label)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// 束の字をすべて書き終え、今日戻ってくる字もないとき
struct NothingTodayView: View {
    @Environment(AppModel.self) var model

    var body: some View {
        VStack(spacing: Space.l) {
            GridCell().frame(width: 72, height: 72)
            Text("今日の分はありません").font(Typo.heading).foregroundStyle(Palette.ink)
            Text("選んだ束の字は、すべて一度書きました。次に戻ってくるまで休むか、設定で束を足してください。")
                .font(Typo.body).foregroundStyle(Palette.sub).multilineTextAlignment(.center)
            Button("束を選ぶ") { model.tab = .settings }
                .buttonStyle(InkButtonStyle(filled: false))
                .frame(maxWidth: 240)
        }
        .padding(Space.xl)
    }
}

/// 折り返して並べる
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
