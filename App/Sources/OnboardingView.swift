import SwiftUI

/// 使い方（3 ページ）。2 ページ目は、書いた字にお手本が重なる動く見本
struct OnboardingView: View {
    @Environment(AppModel.self) var model
    @State var page = 0

    var body: some View {
        VStack(spacing: Space.l) {
            TabView(selection: $page) {
                pageOne.tag(0)
                pageTwo.tag(1)
                pageThree.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i == page ? Palette.fujiDeep : Palette.line)
                        .frame(width: i == page ? 18 : 6, height: 6)
                }
            }
            .animation(.easeOut(duration: 0.25), value: page)
            .accessibilityHidden(true)
            Button(page < 2 ? "次へ" : "今日の稽古を始める") {
                if page < 2 { withAnimation(.easeOut(duration: 0.3)) { page += 1 } } else { model.finishOnboarding() }
            }
            .buttonStyle(InkButtonStyle())
            .padding(.horizontal, Space.xl)
            .frame(maxWidth: 480)
            .padding(.bottom, Space.l)
        }
        .background(Palette.ground.ignoresSafeArea())
    }

    private func pageFrame<Content: View>(title: String, text: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: Space.xl) {
            Spacer(minLength: 0)
            content()
            VStack(spacing: Space.m) {
                Text(title).font(Typo.serif(26)).kerning(-0.5).foregroundStyle(Palette.ink)
                Text(text).font(Typo.body).foregroundStyle(Palette.sub).multilineTextAlignment(.center).lineSpacing(4)
            }
            .padding(.horizontal, Space.xl)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 520)
    }

    private var pageOne: some View {
        pageFrame(title: "読めるのに、書けない。",
                  text: "憂鬱・曖昧・挨拶… キーボードに任せているうちに、手が忘れた字を、毎日 10 字ずつ取り戻します。") {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.m) {
                    SmallLabel("例文のよみを見て、升目に書く")
                    SentenceText(word: WordBook.word("憂鬱")!, revealed: false, size: 20)
                }
                .padding(Space.xl)
                .padding(.top, Space.s)
                .frame(maxWidth: 340, alignment: .leading)
                .background(Hanshi())
                .clipShape(RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous))
                .liftedShadow()
                .rotationEffect(.degrees(-1.5))
                Bunchin().frame(width: 110).offset(y: -4)
            }
        }
    }

    private var pageTwo: some View {
        pageFrame(title: "書いて、重ねて、見比べる。",
                  text: "書き終えたら、お手本を薄墨で重ねます。自動の判定はしません。とめ・はね・はらいまで自分の目で見て、丸をつけます。") {
            OverlayDemo()
        }
    }

    private var pageThree: some View {
        pageFrame(title: "書いた字が、帖になる。",
                  text: "書けなかった字は明日、書けた字は 3・7・14 日あけて戻ってきます。書いた字と記録は、この iPhone の中だけに残ります。") {
            HStack(spacing: 0) {
                TojiBinding(holes: 3)
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("手習い帖").font(Typo.serif(20)).foregroundStyle(Palette.ink)
                    HStack(spacing: 3) {
                        ForEach(0..<14, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Palette.calendar(level: [1, 2, 3, 2, 0, 2, 3, 3, 1, 2, 0, 3, 2, 3][i]))
                                .frame(width: 11, height: 11)
                        }
                    }
                    HStack(spacing: 8) {
                        GradeMark(grade: .good, size: 22)
                        GradeMark(grade: .almost, size: 22)
                        GradeMark(grade: .good, size: 22)
                        GradeMark(grade: .miss, size: 22)
                    }
                }
                .padding(Space.l)
            }
            .background(Palette.paper)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .softShadow()
        }
    }
}

/// 動く見本：手で書いた「三」に、お手本が重なって、はなまるがつく（動きを減らす設定では止まった絵）
struct OverlayDemo: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private static let strokes: [InkStroke] = [
        InkStroke(cell: 0, points: [300, 255, 420, 250, 560, 246, 690, 250]),
        InkStroke(cell: 0, points: [345, 500, 470, 494, 600, 490, 660, 495]),
        InkStroke(cell: 0, points: [205, 770, 380, 760, 560, 758, 760, 762, 815, 770]),
    ]

    var body: some View {
        if reduceMotion {
            demo(written: 3, model: true, mark: 1)
        } else {
            PhaseAnimator([0, 1, 2, 3, 4, 5]) { phase in
                demo(written: min(phase, 3), model: phase >= 4, mark: phase >= 5 ? 1 : 0)
            } animation: { phase in
                phase == 0 ? .easeOut(duration: 0.2) : .easeOut(duration: 0.45)
            }
        }
    }

    private func demo(written: Int, model: Bool, mark: CGFloat) -> some View {
        let size: CGFloat = 150
        return ZStack(alignment: .topTrailing) {
            ZStack {
                GridCell()
                Text("三").font(Typo.serif(size * 0.74)).foregroundStyle(Palette.usuzumi).opacity(model ? 1 : 0)
                InkLayer(strokes: Array(Self.strokes.prefix(written)), cellSize: size, columns: 1)
            }
            .frame(width: size, height: size)
            GradeMark(grade: .good, size: 54, progress: mark)
                .offset(x: 18, y: -18)
                .rotationEffect(.degrees(-6))
        }
        .accessibilityElement()
        .accessibilityLabel("手で書いた字に、お手本を重ねて見比べる見本")
    }
}
