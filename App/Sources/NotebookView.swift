import SwiftUI

/// 手習い帖：書いた字が綴じられていく帖・稽古の暦・苦手・束の進み具合
struct NotebookView: View {
    @Environment(AppModel.self) var model
    @Environment(\.horizontalSizeClass) var sizeClass
    @State var filter: Filter = .recent
    @State var detail: Word?

    enum Filter: String, CaseIterable, Identifiable {
        case recent = "最近", weak = "苦手", mastered = "書ける"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    cover
                    if model.writtenCount == 0 {
                        empty
                    } else {
                        if sizeClass == .regular {
                            HStack(alignment: .top, spacing: Space.xl) {
                                VStack(alignment: .leading, spacing: Space.xl) { calendar; packs }
                                    .frame(maxWidth: 340)
                                words
                            }
                        } else {
                            calendar
                            words
                            packs
                        }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.l)
                .frame(maxWidth: sizeClass == .regular ? 980 : 560)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.ground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $detail) { word in
                WordDetailView(word: word)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Palette.ground)
            }
            .onAppear {
                if model.screenshotScene == "word", let id = model.notebookWordIDs.first { detail = WordBook.word(id) }
                if model.screenshotScene == "weak" { filter = .weak }
            }
        }
    }

    // MARK: - 表紙

    private var cover: some View {
        HStack(spacing: 0) {
            TojiBinding()
            VStack(alignment: .leading, spacing: Space.s) {
                Text("手習い帖").font(Typo.serif(28)).kerning(-1).foregroundStyle(Palette.ink)
                HStack(spacing: Space.l) {
                    figure(model.writtenCount, "綴じた字")
                    figure(model.masteredCount, "書ける字")
                    figure(model.weakWordIDs.count, "苦手")
                }
            }
            .padding(Space.l)
            Spacer()
        }
        .background(Palette.paper)
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).stroke(Palette.line, lineWidth: 0.6))
        .softShadow()
    }

    private func figure(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)").font(Typo.serif(22)).kerning(-0.5).monospacedDigit().foregroundStyle(Palette.ink)
            SmallLabel(label)
        }
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        VStack(spacing: Space.l) {
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in GridCell().frame(width: 44, height: 44) }
            }
            Text("まだ一枚も綴じていません").font(Typo.heading).foregroundStyle(Palette.ink)
            Text("今日の稽古で書いた字が、自分の筆跡のまま、ここに一枚ずつ綴じられます。")
                .font(Typo.body).foregroundStyle(Palette.sub).multilineTextAlignment(.center)
            Button("今日の稽古へ") { model.tab = .today }
                .buttonStyle(InkButtonStyle())
                .frame(maxWidth: 260)
        }
        .padding(.vertical, Space.xl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 暦

    private var calendar: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                SmallLabel("稽古の暦")
                Spacer()
                Text("続けて \(model.streak) 日・合計 \(model.totalDays) 日").font(Typo.small).foregroundStyle(Palette.sub)
            }
            PracticeCalendar(days: model.progress.days, today: model.today, weeks: sizeClass == .regular ? 22 : 18)
        }
    }

    // MARK: - 綴じた字

    private var words: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Picker("見る字", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            let ids = filtered
            if ids.isEmpty {
                Text(filter == .weak ? "苦手の字はありません。書けなかった字は、ここに集まります。" : "7 日あけて書けた字が「書ける字」になります。")
                    .font(Typo.body).foregroundStyle(Palette.sub)
                    .padding(.vertical, Space.l)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.m)], spacing: Space.m) {
                    ForEach(ids, id: \.self) { id in
                        if let word = WordBook.word(id) { tile(word) }
                    }
                }
                if !model.isPro && model.writtenCount > AppModel.freeInkLimit {
                    Button {
                        model.showPaywall = true
                    } label: {
                        Label("\(AppModel.freeInkLimit) 語より前の筆跡は Pro で見返せます", systemImage: "lock")
                            .font(Typo.small)
                    }
                    .foregroundStyle(Palette.fujiDeep)
                }
            }
        }
    }

    private var filtered: [String] {
        let all = model.notebookWordIDs
        switch filter {
        case .recent: return Array(all.prefix(60))
        case .weak: return model.weakWordIDs
        case .mastered: return all.filter { model.progress.states[$0]?.isMastered ?? false }
        }
    }

    private func tile(_ word: Word) -> some View {
        let state = model.progress.states[word.id]
        let visible = model.isInkVisible(word.id) || model.ink[word.id] == nil
        return Button { detail = word } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    InkThumbnail(word: word, sheet: model.ink[word.id], cellSize: word.characters.count > 3 ? 26 : 32, hidden: !visible)
                    Spacer(minLength: 0)
                    if let grade = state?.lastGrade { GradeMark(grade: grade, size: 18) }
                }
                Text(word.reading).font(Typo.small).foregroundStyle(Palette.sub).lineLimit(1)
                LevelDots(level: state?.level ?? 0)
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).stroke(Palette.line, lineWidth: 0.6))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(word.text)、\(word.reading)、\(state?.lastGrade?.label ?? "")")
    }

    // MARK: - 束

    private var packs: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SmallLabel("束の進み具合")
            ForEach(Pack.all) { pack in
                let p = model.packProgress(pack.id)
                let locked = !pack.isFree && !model.isPro
                Button {
                    if locked { model.showPaywall = true }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(pack.title).font(Typo.body).foregroundStyle(Palette.ink)
                            if locked { Image(systemName: "lock").font(.caption2).foregroundStyle(Palette.fujiDeep) }
                            Spacer()
                            Text("\(p.mastered) / \(p.total)").font(Typo.serif(13)).monospacedDigit().foregroundStyle(Palette.sub)
                        }
                        ProgressBar(written: Double(p.written) / Double(max(p.total, 1)), mastered: Double(p.mastered) / Double(max(p.total, 1)))
                    }
                }
                .buttonStyle(.plain)
                .allowsHitTesting(locked)
            }
        }
    }
}

/// 段（0〜6）を小さな点で
struct LevelDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<CardState.intervals.count, id: \.self) { i in
                Circle()
                    .fill(i < level ? (level >= CardState.masteredLevel ? Palette.fujiDeep : Palette.fuji) : Palette.line)
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityLabel("段 \(level)")
    }
}

/// 書いた字（淡い）と書ける字（濃い）の 2 段の帯
struct ProgressBar: View {
    let written: Double
    let mastered: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line.opacity(0.7))
                Capsule().fill(Palette.fuji.opacity(0.55)).frame(width: geo.size.width * written)
                Capsule().fill(Palette.fujiDeep.opacity(0.8)).frame(width: geo.size.width * mastered)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

/// 稽古した日の暦（週ごとの列。濃さは書いた字の数の区切りで決める）
struct PracticeCalendar: View {
    let days: [Day: DayRecord]
    let today: Day
    var weeks = 18

    var body: some View {
        let cell: CGFloat = 11, gap: CGFloat = 3
        Canvas { context, _ in
            let weekday = Calendar.current.component(.weekday, from: today.date()) - 1  // 0 = 日曜
            let start = today.adding(-(weeks - 1) * 7 - weekday)
            for w in 0..<weeks {
                for d in 0..<7 {
                    let day = start.adding(w * 7 + d)
                    guard day <= today else { continue }
                    let level = Streak.level(written: days[day]?.written ?? 0)
                    let rect = CGRect(x: CGFloat(w) * (cell + gap), y: CGFloat(d) * (cell + gap), width: cell, height: cell)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2.5), with: .color(Palette.calendar(level: level)))
                    if day == today {
                        context.stroke(Path(roundedRect: rect.insetBy(dx: -1.5, dy: -1.5), cornerRadius: 3.5), with: .color(Palette.fujiDeep), lineWidth: 1)
                    }
                }
            }
        }
        .frame(width: CGFloat(weeks) * (cell + gap), height: 7 * (cell + gap))
        .accessibilityElement()
        .accessibilityLabel("この \(weeks) 週で \(days.filter { $0.key > today.adding(-weeks * 7) && $0.value.written > 0 }.count) 日稽古しました")
    }
}
