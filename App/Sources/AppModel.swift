import Foundation
import Observation
import SwiftUI

enum AppTab: Hashable { case today, notebook, settings }

/// 保存する記録（UserDefaults に JSON で 1 つ）
struct Progress: Codable, Equatable, Sendable {
    var states: [String: CardState] = [:]
    var days: [Day: DayRecord] = [:]
    var plan: DayPlan?
    var dailyCount: Int = 10
    var enabledPacks: Set<Pack.ID> = [.basic]
}

/// 端末の中だけに保存する（UserDefaults と Application Support のファイル）。テストでは差し替える
protocol ProgressStore: Sendable {
    func loadProgress() -> Progress?
    func saveProgress(_ progress: Progress)
    func loadInk() -> [String: InkSheet]
    func saveInk(_ ink: [String: InkSheet])
}

struct DeviceStore: ProgressStore {
    private let key = "tenarai.progress.v1"

    func loadProgress() -> Progress? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Progress.self, from: data)
    }

    func saveProgress(_ progress: Progress) {
        if let data = try? JSONEncoder().encode(progress) { UserDefaults.standard.set(data, forKey: key) }
    }

    private var inkURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ink.json")
    }

    func loadInk() -> [String: InkSheet] {
        guard let url = inkURL, let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: InkSheet].self, from: data)) ?? [:]
    }

    func saveInk(_ ink: [String: InkSheet]) {
        guard let url = inkURL, let data = try? JSONEncoder().encode(ink) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// 記録を持たない（スクリーンショット用・テスト用）
struct MemoryStore: ProgressStore {
    func loadProgress() -> Progress? { nil }
    func saveProgress(_ progress: Progress) {}
    func loadInk() -> [String: InkSheet] { [:] }
    func saveInk(_ ink: [String: InkSheet]) {}
}

@MainActor
@Observable
final class AppModel {
    static let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.005"
    static let proID = ProductID.pro(bundleID: bundleID)
    /// 無料で帖に見返せる語の数（新しい順）
    static let freeInkLimit = 30
    static let freeDailyCounts = [5, 10, 15]
    static let proDailyCounts = [5, 10, 15, 20]

    var tab: AppTab = .today
    var showPaywall = false
    private(set) var progress: Progress
    private(set) var ink: [String: InkSheet]
    let purchases: PurchaseStore
    let screenshotScene: String?
    private let store: ProgressStore
    private let clock: () -> Date

    @ObservationIgnored private let defaults: UserDefaults
    var onboardingDone: Bool
    var hapticsOn: Bool {
        didSet { defaults.set(!hapticsOn, forKey: "tenarai.hapticsOff") }
    }

    init(store: ProgressStore? = nil, clock: @escaping () -> Date = Date.init, defaults: UserDefaults = .standard) {
        let scene = defaults.string(forKey: "screenshotScene")
        screenshotScene = (scene?.isEmpty ?? true) ? nil : scene
        let chosen: ProgressStore = store ?? (screenshotScene != nil ? MemoryStore() : DeviceStore())
        self.store = chosen
        self.clock = clock
        self.defaults = defaults
        hapticsOn = !defaults.bool(forKey: "tenarai.hapticsOff")
        progress = chosen.loadProgress() ?? Progress()
        ink = chosen.loadInk()
        purchases = PurchaseStore(productIDs: [Self.proID], proProductIDs: [Self.proID])
        onboardingDone = screenshotScene.map { $0 != "onboarding" } ?? defaults.bool(forKey: "tenarai.onboardingDone")
        if let screenshotScene { Sample.fill(self, scene: screenshotScene) }
    }

    // MARK: - 権利

    var isPro: Bool { purchases.entitlements.isPro || screenshotScene == "pro" }

    var unlockedPacks: [Pack.ID] {
        Pack.ID.allCases.filter { id in Pack.pack(id).isFree || isPro }
    }

    var activePacks: [Pack.ID] {
        let active = unlockedPacks.filter { progress.enabledPacks.contains($0) }
        return active.isEmpty ? [.basic] : active
    }

    var activeWords: [Word] { activePacks.flatMap { WordBook.words(in: $0) } }

    // MARK: - 日付

    var today: Day { Day(clock()) }

    // MARK: - 今日の稽古

    /// 今日の稽古（日が変わったら作り直す）
    var todayPlan: DayPlan {
        if let plan = progress.plan, plan.day == today { return plan }
        return Scheduler.plan(day: today, count: progress.dailyCount, states: progress.states, words: activeWords)
    }

    func ensureTodayPlan() {
        if progress.plan?.day != today {
            progress.plan = todayPlan
            save()
        }
    }

    /// 苦手だけの稽古（Pro）に切り替える
    func startWeakPractice() {
        progress.plan = Scheduler.plan(day: today, count: progress.dailyCount, states: progress.states, words: activeWords, weakOnly: true)
        save()
    }

    /// 今日の分のあと、もう少し（新しい字を足す）
    func extendToday() {
        var plan = todayPlan
        let more = Scheduler.plan(day: today, count: 5, states: progress.states, words: activeWords)
        plan.wordIDs += more.wordIDs.filter { !plan.wordIDs.contains($0) }
        progress.plan = plan
        save()
    }

    var weakWordIDs: [String] {
        progress.states.filter { $0.value.isWeak }.sorted { $0.value.misses > $1.value.misses }.map(\.key)
    }

    func record(_ grade: Grade, for wordID: String, sheet: InkSheet) {
        var plan = todayPlan
        guard plan.results[wordID] == nil else { return }
        plan.results[wordID] = grade
        progress.plan = plan
        var state = progress.states[wordID] ?? CardState(due: today)
        state.apply(grade, on: today)
        progress.states[wordID] = state
        var record = progress.days[today] ?? DayRecord()
        record.written += 1
        if grade == .good { record.good += 1 }
        progress.days[today] = record
        if !sheet.isEmpty {
            var stamped = sheet
            stamped.day = today
            ink[wordID] = stamped
            store.saveInk(ink)
        }
        save()
    }

    // MARK: - 記録の見え方

    var practicedDays: Set<Day> { Set(progress.days.filter { $0.value.written > 0 }.keys) }
    var streak: Int { Streak.current(days: practicedDays, today: today) }
    var totalDays: Int { practicedDays.count }
    var masteredCount: Int { progress.states.values.filter(\.isMastered).count }
    var writtenCount: Int { progress.states.count }
    var tomorrowCount: Int {
        Scheduler.dueCount(on: today.adding(1), states: progress.states, available: Set(activeWords.map(\.id)))
    }

    /// 帖に綴じた語（新しく書いた順）
    var notebookWordIDs: [String] {
        progress.states
            .sorted { ($0.value.lastDay ?? Day(0), $0.key) > ($1.value.lastDay ?? Day(0), $1.key) }
            .map(\.key)
    }

    /// 無料で見返せるのは新しい順に 30 語
    func isInkVisible(_ wordID: String) -> Bool {
        if isPro { return true }
        guard let index = notebookWordIDs.firstIndex(of: wordID) else { return true }
        return index < Self.freeInkLimit
    }

    func packProgress(_ id: Pack.ID) -> (mastered: Int, written: Int, total: Int) {
        let words = WordBook.words(in: id)
        let states = words.compactMap { progress.states[$0.id] }
        return (states.filter(\.isMastered).count, states.count, words.count)
    }

    // MARK: - 設定

    var dailyCountChoices: [Int] { isPro ? Self.proDailyCounts : Self.freeDailyCounts }

    func setDailyCount(_ count: Int) {
        guard dailyCountChoices.contains(count) else { return }
        progress.dailyCount = count
        if let plan = progress.plan, plan.day == today, plan.results.isEmpty { progress.plan = nil }
        save()
    }

    func setPack(_ id: Pack.ID, enabled: Bool) {
        guard unlockedPacks.contains(id) else { showPaywall = true; return }
        if enabled { progress.enabledPacks.insert(id) } else { progress.enabledPacks.remove(id) }
        if progress.enabledPacks.isEmpty { progress.enabledPacks = [.basic] }
        if let plan = progress.plan, plan.day == today, plan.results.isEmpty { progress.plan = nil }
        save()
    }

    func finishOnboarding() {
        defaults.set(true, forKey: "tenarai.onboardingDone")
        withAnimation(.easeOut(duration: 0.35)) { onboardingDone = true }
    }

    func replayOnboarding() {
        onboardingDone = false
    }

    // MARK: - 課金の画面

    /// 価値を感じた直後（今日の稽古を書き終えた）にだけ、1 日 1 回まで出す
    func offerProAfterFinishing() {
        let key = "tenarai.paywallShownDay"
        guard !isPro, screenshotScene == nil, defaults.object(forKey: key) as? Int != today.index else { return }
        defaults.set(today.index, forKey: key)
        showPaywall = true
    }

    // MARK: - 内部

    func replaceForSample(progress: Progress, ink: [String: InkSheet]) {
        self.progress = progress
        self.ink = ink
    }

    private func save() { store.saveProgress(progress) }
}
