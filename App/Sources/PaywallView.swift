import StoreKit
import SwiftUI

/// Pro（買い切り）。今日の稽古を書き終えた直後と、鍵のついた所を押したときだけ出す
struct PaywallView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    @State var buying = false
    @State var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                HStack {
                    Spacer()
                    Button("閉じる") { dismiss() }.font(Typo.body).foregroundStyle(Palette.fujiDeep)
                }
                VStack(alignment: .leading, spacing: Space.s) {
                    SmallLabel("手習い帖 Pro")
                    Text("書けない字を、\nもっと深く。").font(Typo.serif(30)).kerning(-1).foregroundStyle(Palette.ink)
                    Text("一度買えば、ずっと使えます。広告もサブスクもありません。")
                        .font(Typo.body).foregroundStyle(Palette.sub)
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    SmallLabel("追加の束 4 つ・\(proWordCount) 語")
                    ForEach(Pack.all.filter { !$0.isFree }) { pack in
                        PackPreview(pack: pack)
                    }
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    feature("arrow.clockwise", "苦手だけの稽古", "書けなかった字だけを集めて、何度でも。")
                    feature("square.grid.3x3", "1 日 20 字まで", "試験の前や、時間のある日に。")
                    feature("book.closed", "帖を全部見返す", "無料は新しい 30 語まで。Pro は書いた字をすべて、自分の筆跡で。")
                }

                purchaseArea
            }
            .padding(Space.xl)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.ground)
        .task { if model.purchases.loadState == .idle { await model.purchases.load() } }
    }

    private var proWordCount: Int { Pack.all.filter { !$0.isFree }.reduce(0) { $0 + WordBook.words(in: $1.id).count } }

    private func feature(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Palette.fujiDeep)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Palette.fujiSoft))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.heading).foregroundStyle(Palette.ink)
                Text(text).font(Typo.small).foregroundStyle(Palette.sub)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var purchaseArea: some View {
        VStack(spacing: Space.m) {
            if model.isPro {
                Label("Pro を使っています", systemImage: "checkmark.seal").foregroundStyle(Palette.fujiDeep)
            } else {
                switch model.purchases.loadState {
                case .idle, .loading:
                    ProgressView("読み込んでいます…").frame(minHeight: 52)
                case .unavailable:
                    VStack(spacing: Space.s) {
                        Text("いまは購入できません。通信のよいところで、もう一度開いてください。")
                            .font(Typo.small).foregroundStyle(Palette.sub).multilineTextAlignment(.center)
                        Button("もう一度読み込む") { Task { await model.purchases.load() } }
                            .buttonStyle(InkButtonStyle(filled: false))
                    }
                case .ready:
                    if let product = model.purchases.products.first {
                        Button {
                            buy(product)
                        } label: {
                            Text(buying ? "手続きしています…" : "\(product.displayPrice) で Pro にする（買い切り）")
                        }
                        .buttonStyle(InkButtonStyle())
                        .disabled(buying)
                        Text("ファミリー共有に対応。更新の課金はありません。")
                            .font(Typo.small).foregroundStyle(Palette.sub)
                    }
                }
            }
            if let message { Text(message).font(Typo.small).foregroundStyle(Palette.sub) }
            Button("購入を復元") {
                Task {
                    await model.purchases.restore()
                    message = model.isPro ? "Pro を復元しました。" : "復元できる購入は見つかりませんでした。"
                }
            }
            .font(Typo.small)
            .foregroundStyle(Palette.fujiDeep)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
    }

    private func buy(_ product: Product) {
        buying = true
        Task {
            let outcome = await model.purchases.purchase(product)
            buying = false
            switch outcome {
            case .purchased: dismiss()
            case .pending: message = "承認を待っています。承認されると Pro になります。"
            case .failed: message = "購入できませんでした。時間をおいて、もう一度お試しください。"
            case .cancelled: break
            }
        }
    }
}

/// 束の中身の見本（最初の字を小さな升目で）
struct PackPreview: View {
    let pack: Pack

    var body: some View {
        let words = WordBook.words(in: pack.id)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pack.title).font(Typo.heading).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(words.count) 語").font(Typo.serif(13)).monospacedDigit().foregroundStyle(Palette.sub)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(words.prefix(6)) { word in
                        InkThumbnail(word: word, sheet: nil, cellSize: 24)
                    }
                }
            }
            .accessibilityLabel("例：" + words.prefix(6).map(\.text).joined(separator: "、"))
        }
        .padding(Space.m)
        .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).stroke(Palette.line, lineWidth: 0.6))
    }
}
