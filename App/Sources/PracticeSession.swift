import SwiftUI

/// 1 字ずつ：例文のよみを見て升目に書く → お手本を重ねる → 自分で丸をつける
/// iPhone Duo の内側（regular）では見開き：左のページに例文、右のページに大きな升目
struct PracticeSession: View {
    @Environment(AppModel.self) var model
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var sheet = InkSheet()
    @State var revealed = false
    @State var graded: Grade?
    @State var markProgress: CGFloat = 0
    @State var shake = 0
    @State var revealTick = 0
    @State var goodTick = 0
    @State var almostTick = 0
    @State var missTick = 0
    @State var combo = 0
    @State var didAutoReveal = false

    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        let plan = model.todayPlan
        if let id = plan.nextWordID, let word = WordBook.word(id) {
            content(word: word, plan: plan)
                .id(word.id)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
                .sensoryFeedback(.selection, trigger: revealTick) { _, _ in model.hapticsOn }
                .sensoryFeedback(.success, trigger: goodTick) { _, _ in model.hapticsOn }
                .sensoryFeedback(.impact(weight: .light), trigger: almostTick) { _, _ in model.hapticsOn }
                .sensoryFeedback(.warning, trigger: missTick) { _, _ in model.hapticsOn }
                .onAppear {
                    if model.screenshotScene == "answer", !didAutoReveal { didAutoReveal = true; revealed = true }
                }
        }
    }

    @ViewBuilder
    private func content(word: Word, plan: DayPlan) -> some View {
        GeometryReader { geo in
            if isWide {
                HStack(spacing: 0) {
                    leftPage(word: word, plan: plan)
                        .frame(width: geo.size.width * 0.42)
                    PageGutter()
                    rightPage(word: word, available: CGSize(width: geo.size.width * 0.58 - 18, height: geo.size.height))
                }
            } else {
                VStack(spacing: Space.l) {
                    progressHeader(plan: plan, word: word)
                    SentenceText(word: word, revealed: revealed, size: 21)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // 半紙に文鎮を置いた上で書く
                    ZStack(alignment: .top) {
                        Hanshi()
                            .clipShape(RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous).stroke(Palette.line, lineWidth: 0.6))
                            .softShadow()
                        pad(word: word, available: CGSize(width: geo.size.width - Space.xl * 2 - Space.l * 2, height: geo.size.height * 0.48))
                            .frame(maxHeight: .infinity)
                        Bunchin().frame(width: 130).offset(y: -4)
                    }
                    .frame(maxHeight: .infinity)
                    controls(word: word)
                }
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.l)
            }
        }
    }

    // MARK: - 見開き

    private func leftPage(word: Word, plan: DayPlan) -> some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            progressHeader(plan: plan, word: word)
            SentenceText(word: word, revealed: revealed, size: 24)
            if revealed {
                VStack(alignment: .leading, spacing: 6) {
                    SmallLabel("よみ")
                    Text(word.reading).font(Typo.serif(18)).foregroundStyle(Palette.ink)
                    SmallLabel(Pack.pack(word.pack).title)
                        .padding(.top, Space.s)
                }
                .transition(.opacity)
            }
            Spacer()
            controls(word: word)
        }
        .padding(Space.xl)
        .background(Palette.paper)
    }

    private func rightPage(word: Word, available: CGSize) -> some View {
        ZStack {
            Hanshi()
            VStack(spacing: Space.l) {
                Bunchin().frame(width: 160)
                Spacer(minLength: 0)
                pad(word: word, available: CGSize(width: available.width - Space.xl * 2, height: available.height * 0.7))
                Spacer(minLength: 0)
            }
            .padding(Space.xl)
        }
    }

    // MARK: - 部品

    private func progressHeader(plan: DayPlan, word: Word) -> some View {
        let isReview = plan.wordIDs.firstIndex(of: word.id).map { $0 < plan.reviewCount } ?? false
        return HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(plan.position + 1)")
                    .font(Typo.serif(30)).kerning(-1).monospacedDigit()
                    .contentTransition(.numericText())
                Text("/ \(plan.wordIDs.count)").font(Typo.serif(15)).foregroundStyle(Palette.sub).monospacedDigit()
            }
            .foregroundStyle(Palette.ink)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(plan.wordIDs.count) 字のうち \(plan.position + 1) 字目")
            Spacer()
            if combo >= 3 {
                Text("\(combo) 連続")
                    .font(Typo.label).kerning(0.6)
                    .foregroundStyle(Palette.peachDeep)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(Capsule().stroke(Palette.peach, lineWidth: 1))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            SmallLabel(plan.weakOnly ? "苦手の字" : (isReview ? "戻ってきた字" : "はじめての字"),
                       color: isReview || plan.weakOnly ? Palette.fujiDeep : Palette.sub)
        }
    }

    private func pad(word: Word, available: CGSize) -> some View {
        let count = word.characters.count
        let columns = CellLayout.columns(count: count, isWide: isWide)
        let rows = (count + columns - 1) / columns
        let byWidth = (available.width - CGFloat(columns - 1) * 6) / CGFloat(columns)
        let byHeight = (available.height - CGFloat(rows - 1) * 6) / CGFloat(rows)
        let cell = max(60, min(byWidth, byHeight, isWide ? 220 : 170))
        return ZStack(alignment: .topTrailing) {
            WritingPad(word: word, sheet: $sheet, cellSize: cell, columns: columns, showModel: revealed, editable: graded == nil)
                .modifier(Shake(amount: CGFloat(shake)))
            if let graded {
                GradeMark(grade: graded, size: min(cell * 0.7, 72), progress: markProgress)
                    .offset(x: 14, y: -18)
                    .rotationEffect(.degrees(-6))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.35), value: revealed)
    }

    @ViewBuilder
    private func controls(word: Word) -> some View {
        if !revealed {
            VStack(spacing: Space.m) {
                HStack(spacing: Space.m) {
                    Button { sheet.undo() } label: { Label("一画もどす", systemImage: "arrow.uturn.backward") }
                        .disabled(sheet.isEmpty)
                    Spacer()
                    Button { sheet.strokes.removeAll() } label: { Label("書き直す", systemImage: "eraser") }
                        .disabled(sheet.isEmpty)
                }
                .font(Typo.small)
                .foregroundStyle(Palette.fujiDeep)
                .frame(minHeight: 44)
                Button(sheet.isEmpty ? "思い出せない・お手本を見る" : "お手本と見比べる") {
                    revealTick += 1
                    withAnimation(.easeOut(duration: 0.35)) { revealed = true }
                }
                .buttonStyle(InkButtonStyle(filled: !sheet.isEmpty))
            }
        } else {
            VStack(spacing: Space.s) {
                SmallLabel("見比べて、自分で丸をつける")
                HStack(spacing: Space.s) {
                    ForEach(Grade.allCases, id: \.self) { grade in
                        Button { mark(word: word, grade) } label: {
                            VStack(spacing: 4) {
                                GradeMark(grade: grade, size: 26)
                                Text(grade.label).font(Typo.small)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .foregroundStyle(Palette.ink)
                            .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Palette.paper))
                            .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).stroke(Palette.line, lineWidth: 0.8))
                        }
                        .buttonStyle(PressStyle())
                        .disabled(graded != nil)
                    }
                }
            }
            .transition(.opacity)
        }
    }

    private func mark(word: Word, _ grade: Grade) {
        graded = grade
        switch grade {
        case .good:
            goodTick += 1
            withAnimation(.easeOut(duration: 0.25)) { combo += 1 }
        case .almost:
            almostTick += 1
            combo = 0
        case .miss:
            missTick += 1
            combo = 0
            if !reduceMotion { withAnimation(.linear(duration: 0.35)) { shake += 1 } }
        }
        if reduceMotion { markProgress = 1 } else { withAnimation(.easeOut(duration: 0.5)) { markProgress = 1 } }
        let finished = sheet
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            withAnimation(.easeOut(duration: 0.3)) {
                model.record(grade, for: word.id, sheet: finished)
                sheet = InkSheet()
                revealed = false
                graded = nil
                markProgress = 0
            }
            if model.todayPlan.isDone {
                try? await Task.sleep(for: .milliseconds(1200))
                model.offerProAfterFinishing()
            }
        }
    }
}

/// 押すと少し沈む
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 書けなかったときの小さな横揺れ（減衰）
struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = amount - amount.rounded(.down)
        let offset = sin(progress * .pi * 6) * 5 * (1 - progress)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
