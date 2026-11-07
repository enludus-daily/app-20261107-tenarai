import UIKit
import SwiftUI

/// 今日の一枚：今日書いた字を半紙に並べ、自分でつけた丸と一緒に残す
struct DoneView: View {
    @Environment(AppModel.self) var model
    @State var placed = false
    @State var shareImage: Image?
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        let plan = model.todayPlan
        ScrollView {
            VStack(spacing: Space.xl) {
                VStack(spacing: 4) {
                    SmallLabel("今日の稽古、おしまい")
                    Text(summary(plan)).font(Typo.serif(22)).kerning(-0.5).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                }
                TodaySheet(plan: plan)
                    .rotationEffect(.degrees(placed || reduceMotion ? -1.2 : -4))
                    .scaleEffect(placed || reduceMotion ? 1 : 0.96)
                    .opacity(placed || reduceMotion ? 1 : 0)
                    .liftedShadow()
                    .padding(.horizontal, Space.s)
                StatsStrip()
                Text(tomorrowText)
                    .font(Typo.body).foregroundStyle(Palette.sub).multilineTextAlignment(.center)
                VStack(spacing: Space.m) {
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("今日の一枚", image: shareImage)) {
                            Label("今日の一枚を共有", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(InkButtonStyle())
                    }
                    HStack(spacing: Space.m) {
                        Button("もう 5 字") { withAnimation(.easeOut(duration: 0.3)) { model.extendToday() } }
                            .buttonStyle(InkButtonStyle(filled: false))
                        Button {
                            if model.isPro {
                                withAnimation(.easeOut(duration: 0.3)) { model.startWeakPractice() }
                            } else {
                                model.showPaywall = true
                            }
                        } label: {
                            Label("苦手だけ", systemImage: model.isPro ? "arrow.clockwise" : "lock")
                        }
                        .buttonStyle(InkButtonStyle(filled: false))
                        .disabled(model.isPro && model.weakWordIDs.isEmpty)
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.xl)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.1)) { placed = true }
            renderShareImage(plan)
        }
    }

    private func summary(_ plan: DayPlan) -> String {
        let good = plan.goodCount
        if good == plan.wordIDs.count { return "\(good) 字、ぜんぶ書けました" }
        return "\(plan.wordIDs.count) 字のうち \(good) 字にはなまる"
    }

    private var tomorrowText: String {
        let count = model.tomorrowCount
        return count == 0 ? "明日は新しい字から始まります。" : "明日は \(count) 字が戻ってきます。"
    }

    @MainActor
    private func renderShareImage(_ plan: DayPlan) {
        let card = TodaySheet(plan: plan, forShare: true)
            .environment(model)
            .frame(width: 360)
            .padding(24)
            .background(Palette.ground)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }
}

/// 半紙に今日の字を並べた一枚
struct TodaySheet: View {
    @Environment(AppModel.self) var model
    let plan: DayPlan
    var forShare = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack(alignment: .firstTextBaseline) {
                    Text(plan.day.date().formatted(.dateTime.year().month(.defaultDigits).day()))
                        .font(Typo.serif(15)).foregroundStyle(Palette.ink)
                    Spacer()
                    SmallLabel("手習い帖")
                }
                .padding(.top, Space.s)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Space.m, alignment: .leading)], alignment: .leading, spacing: Space.m) {
                    ForEach(plan.wordIDs, id: \.self) { id in
                        if let word = WordBook.word(id) {
                            HStack(spacing: 6) {
                                InkThumbnail(word: word, sheet: model.ink[id], cellSize: word.characters.count > 3 ? 24 : 30)
                                if let grade = plan.results[id] {
                                    GradeMark(grade: grade, size: 20)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(word.text) \(plan.results[id]?.label ?? "")")
                        }
                    }
                }
                HStack(spacing: Space.l) {
                    count(.good)
                    count(.almost)
                    count(.miss)
                    Spacer()
                }
            }
            .padding(Space.xl)
            .background(Hanshi())
            .clipShape(RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.tiny, style: .continuous).stroke(Palette.line, lineWidth: 0.6))
            Bunchin().frame(width: 140).offset(y: -4)
        }
    }

    private func count(_ grade: Grade) -> some View {
        HStack(spacing: 4) {
            GradeMark(grade: grade, size: 16)
            Text("\(plan.results.values.filter { $0 == grade }.count)")
                .font(Typo.serif(15)).monospacedDigit().foregroundStyle(Palette.ink)
        }
    }
}
