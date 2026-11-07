import SwiftUI

/// 綴じた 1 語：自分の筆跡にお手本を重ねて見返す
struct WordDetailView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    let word: Word
    @State var showModel = true
    @State var sheet = InkSheet()

    var body: some View {
        let state = model.progress.states[word.id]
        let visible = model.isInkVisible(word.id)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                HStack {
                    SmallLabel(Pack.pack(word.pack).title)
                    Spacer()
                    Button("閉じる") { dismiss() }.font(Typo.body).foregroundStyle(Palette.fujiDeep)
                }
                ZStack(alignment: .top) {
                    Hanshi().clipShape(RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous))
                    VStack(spacing: Space.l) {
                        if visible {
                            WritingPad(word: word, sheet: $sheet, cellSize: cellSize, columns: word.characters.count,
                                       showModel: showModel, editable: false)
                        } else {
                            VStack(spacing: Space.s) {
                                Image(systemName: "lock").foregroundStyle(Palette.fujiDeep)
                                Text("この筆跡は Pro で見返せます").font(Typo.body).foregroundStyle(Palette.sub)
                                Button("Pro を見る") { model.showPaywall = true }.font(Typo.body)
                            }
                            .frame(height: cellSize)
                        }
                        Toggle("お手本を重ねる", isOn: $showModel.animation(.easeOut(duration: 0.3)))
                            .font(Typo.small)
                            .tint(Palette.fujiDeep)
                            .disabled(!visible)
                    }
                    .padding(Space.xl)
                    .padding(.top, Space.s)
                    Bunchin().frame(width: 120).offset(y: -4)
                }
                .overlay(RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous).stroke(Palette.line, lineWidth: 0.6))
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(word.reading).font(Typo.serif(15)).foregroundStyle(Palette.sub)
                    SentenceText(word: word, revealed: true, size: 20)
                }
                if let state {
                    HStack(spacing: 0) {
                        cellText("\(state.reviews)", "書いた回数")
                        cellText("\(state.misses)", "書けなかった")
                        cellText(nextText(state), "次に戻る日")
                    }
                    .padding(.vertical, Space.m)
                    .background(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).fill(Palette.paper))
                    .overlay(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).stroke(Palette.line, lineWidth: 0.6))
                    LevelDots(level: state.level)
                }
                if model.ink[word.id] == nil {
                    Text("この字は、お手本を見てから丸をつけたので筆跡は残っていません。次に戻ってきたら、升目に書いてみてください。")
                        .font(Typo.small).foregroundStyle(Palette.sub)
                }
            }
            .padding(Space.xl)
        }
        .onAppear { sheet = model.ink[word.id] ?? InkSheet() }
    }

    private var cellSize: CGFloat { word.characters.count >= 4 ? 72 : (word.characters.count == 3 ? 92 : 120) }

    private func nextText(_ state: CardState) -> String {
        let days = state.due.index - model.today.index
        if days <= 0 { return "今日" }
        if days == 1 { return "明日" }
        return "\(days) 日後"
    }

    private func cellText(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Typo.serif(20)).monospacedDigit().foregroundStyle(Palette.ink)
            SmallLabel(label)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
