import Foundation
import Testing
@testable import Tenarai

struct WordBookTests {
    @Test func everyPackHasEnoughWords() {
        #expect(WordBook.words(in: .basic).count >= 150)
        for pack in Pack.ID.allCases where pack != .basic {
            #expect(WordBook.words(in: pack).count >= 40, "\(pack)")
        }
        #expect(WordBook.all.count >= 350)
    }

    @Test func wordIDsAreUniqueAcrossPacks() {
        let ids = WordBook.all.map(\.id)
        #expect(Set(ids).count == ids.count, "重複: \(Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted())")
    }

    @Test func wordsAreKanjiOnlyAndReadingsAreHiragana() {
        for word in WordBook.all {
            #expect(!word.text.isEmpty && word.text.count <= 4, "\(word.text)")
            #expect(word.text.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) || $0 == "々" }, "\(word.text)")
            #expect(word.reading.unicodeScalars.allSatisfy { (0x3041...0x309F).contains($0.value) || $0 == "ー" }, "\(word.text) \(word.reading)")
        }
    }

    @Test func sentencesHaveOneBlankAndDoNotGiveAwayTheWord() {
        for word in WordBook.all {
            #expect(word.sentence.components(separatedBy: "{}").count == 2, "\(word.text)")
            #expect(!word.sentence.contains(word.text), "\(word.text)")
            #expect(word.filledSentence.contains(word.text))
        }
    }

    @Test func parseSkipsBrokenLines() {
        let words = WordBook.parse("憂鬱|ゆううつ|少し{}だ\n# memo\n\n壊れた行\n", pack: .basic)
        #expect(words.map(\.text) == ["憂鬱"])
        #expect(words[0].sentenceParts.before == "少し")
        #expect(words[0].sentenceParts.after == "だ")
    }
}

struct CardStateTests {
    let day = Day(1000)

    @Test func goodMovesUpAndSpacesOut() {
        var state = CardState(due: day)
        state.apply(.good, on: day)
        #expect(state.level == 1)
        #expect(state.due == day.adding(1))
        state.apply(.good, on: state.due)
        #expect(state.level == 2)
        #expect(state.due == day.adding(1 + 3))
    }

    @Test func missResetsAndComesBackTomorrow() {
        var state = CardState(level: 3, due: day)
        state.apply(.miss, on: day)
        #expect(state.level == 0)
        #expect(state.misses == 1)
        #expect(state.due == day.adding(1))
        #expect(state.isWeak)
    }

    @Test func almostKeepsLevelAndComesBackTomorrow() {
        var state = CardState(level: 2, due: day)
        state.apply(.almost, on: day)
        #expect(state.level == 2)
        #expect(state.due == day.adding(1))
        #expect(!state.isWeak)
    }

    @Test func levelStopsAtTheLongestInterval() {
        var state = CardState(level: CardState.intervals.count, due: day)
        state.apply(.good, on: day)
        #expect(state.level == CardState.intervals.count)
        #expect(state.due == day.adding(60))
        #expect(state.isMastered)
    }
}

struct SchedulerTests {
    let today = Day(2000)
    let words = WordBook.words(in: .basic)

    @Test func newUserGetsNewWordsInOrder() {
        let plan = Scheduler.plan(day: today, count: 10, states: [:], words: words)
        #expect(plan.wordIDs == words.prefix(10).map(\.id))
        #expect(plan.reviewCount == 0)
        #expect(plan.newCount == 10)
    }

    @Test func dueWordsComeFirstThenNewOnes() {
        let states: [String: CardState] = [
            words[0].id: CardState(level: 1, due: today.adding(-1)),
            words[1].id: CardState(level: 2, due: today.adding(3)),  // まだ
            words[2].id: CardState(level: 0, due: today, misses: 2),
        ]
        let plan = Scheduler.plan(day: today, count: 5, states: states, words: words)
        #expect(plan.wordIDs.prefix(2) == [words[0].id, words[2].id])
        #expect(plan.reviewCount == 2)
        #expect(!plan.wordIDs.contains(words[1].id))
        #expect(plan.wordIDs.count == 5)
    }

    @Test func tooManyDueWordsFillTheWholeDay() {
        var states: [String: CardState] = [:]
        for word in words.prefix(30) { states[word.id] = CardState(due: today.adding(-2)) }
        let plan = Scheduler.plan(day: today, count: 10, states: states, words: words)
        #expect(plan.reviewCount == 10)
        #expect(plan.newCount == 0)
    }

    @Test func weakOnlyPicksMissedWords() {
        var miss = CardState(due: today)
        miss.apply(.miss, on: today.adding(-1))
        var good = CardState(due: today)
        good.apply(.good, on: today.adding(-1))
        let plan = Scheduler.plan(day: today, count: 10, states: [words[0].id: miss, words[1].id: good], words: words, weakOnly: true)
        #expect(plan.wordIDs == [words[0].id])
        #expect(plan.weakOnly)
    }

    @Test func wordsOutsideTheChosenPacksAreNotPlanned() {
        let yoji = WordBook.words(in: .yoji)
        let states = [yoji[0].id: CardState(due: today.adding(-1))]
        let plan = Scheduler.plan(day: today, count: 3, states: states, words: words)
        #expect(!plan.wordIDs.contains(yoji[0].id))
    }

    @Test func planIsDoneWhenEveryWordHasAMark() {
        var plan = Scheduler.plan(day: today, count: 2, states: [:], words: words)
        #expect(!plan.isDone)
        plan.results[plan.wordIDs[0]] = .good
        #expect(plan.nextWordID == plan.wordIDs[1])
        plan.results[plan.wordIDs[1]] = .miss
        #expect(plan.isDone)
        #expect(plan.goodCount == 1)
    }
}

struct StreakTests {
    let today = Day(500)

    @Test func countsBackFromToday() {
        let days: Set<Day> = [today, today.adding(-1), today.adding(-2), today.adding(-4)]
        #expect(Streak.current(days: days, today: today) == 3)
    }

    @Test func yesterdayStillCountsBeforePracticingToday() {
        let days: Set<Day> = [today.adding(-1), today.adding(-2)]
        #expect(Streak.current(days: days, today: today) == 2)
    }

    @Test func gapEndsTheStreak() {
        #expect(Streak.current(days: [today.adding(-2)], today: today) == 0)
    }

    @Test(arguments: [(0, 0), (1, 1), (4, 1), (5, 2), (9, 2), (10, 3), (40, 3)])
    func calendarLevelUsesFixedSteps(written: Int, level: Int) {
        #expect(Streak.level(written: written) == level)
    }

    @Test func dayFollowsTheCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 1))!
        let night = calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 23))!
        let next = calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 0, minute: 5))!
        #expect(Day(morning, calendar: calendar) == Day(night, calendar: calendar))
        #expect(Day(next, calendar: calendar) == Day(night, calendar: calendar).adding(1))
    }
}

struct InkTests {
    @Test func strokesKeepTheirShapeAtAnySize() {
        var stroke = InkStroke(cell: 0, points: [])
        stroke.append(CGPoint(x: 10, y: 20), cellSize: 100)
        stroke.append(CGPoint(x: 50, y: 80), cellSize: 100)
        #expect(stroke.points == [100, 200, 500, 800])
        let big = stroke.cgPoints(cellSize: 200)
        #expect(big == [CGPoint(x: 20, y: 40), CGPoint(x: 100, y: 160)])
    }

    @Test func repeatedPointsAreDropped() {
        var stroke = InkStroke(cell: 0, points: [])
        stroke.append(CGPoint(x: 10, y: 10), cellSize: 100)
        stroke.append(CGPoint(x: 10, y: 10), cellSize: 100)
        #expect(stroke.pointCount == 1)
    }

    @Test func sheetRoundTripsAndUndoes() throws {
        var sheet = InkSheet(strokes: [InkStroke(cell: 0, points: [1, 2]), InkStroke(cell: 1, points: [3, 4])])
        let data = try JSONEncoder().encode(sheet)
        #expect(try JSONDecoder().decode(InkSheet.self, from: data) == sheet)
        #expect(sheet.strokes(inCell: 1).count == 1)
        sheet.undo()
        #expect(sheet.strokes.count == 1)
    }

    @Test func cellLayoutWrapsLongWordsOnNarrowScreens() {
        #expect(CellLayout.columns(count: 4, isWide: false) == 2)
        #expect(CellLayout.columns(count: 4, isWide: true) == 4)
        #expect(CellLayout.columns(count: 2, isWide: false) == 2)
        // 2 列・升目 100・間 10 のとき、(150, 130) は 2 段目の右 = 3 番目
        #expect(CellLayout.cell(at: CGPoint(x: 150, y: 130), cellSize: 100, gap: 10, columns: 2, count: 4) == 3)
        // 升目の外は一番近い升目に
        #expect(CellLayout.cell(at: CGPoint(x: 999, y: 999), cellSize: 100, gap: 10, columns: 2, count: 3) == 2)
        #expect(CellLayout.origin(of: 3, cellSize: 100, gap: 10, columns: 2) == CGPoint(x: 110, y: 110))
    }
}

/// 記録を覚えておく偽物
final class FakeStore: ProgressStore, @unchecked Sendable {
    var progress: Progress?
    var ink: [String: InkSheet] = [:]
    func loadProgress() -> Progress? { progress }
    func saveProgress(_ progress: Progress) { self.progress = progress }
    func loadInk() -> [String: InkSheet] { ink }
    func saveInk(_ ink: [String: InkSheet]) { self.ink = ink }
}

@MainActor
struct AppModelTests {
    func makeModel(store: FakeStore = FakeStore(), date: Date = Date(timeIntervalSinceReferenceDate: 815_000_000)) -> AppModel {
        let defaults = UserDefaults(suiteName: "tenarai.tests.\(UUID().uuidString)")!
        return AppModel(store: store, clock: { date }, defaults: defaults)
    }

    @Test func recordingAWordSavesStateDayAndInk() {
        let store = FakeStore()
        let model = makeModel(store: store)
        model.ensureTodayPlan()
        let first = model.todayPlan.wordIDs[0]
        let sheet = InkSheet(strokes: [InkStroke(cell: 0, points: [10, 10, 500, 500])])
        model.record(.good, for: first, sheet: sheet)
        #expect(model.progress.states[first]?.level == 1)
        #expect(model.progress.days[model.today]?.written == 1)
        #expect(model.ink[first]?.strokes.count == 1)
        #expect(store.ink[first]?.day == model.today)
        #expect(store.progress?.plan?.results[first] == .good)
        #expect(model.streak == 1)
    }

    @Test func recordingTwiceDoesNotCountTwice() {
        let model = makeModel()
        let first = model.todayPlan.wordIDs[0]
        model.record(.good, for: first, sheet: InkSheet())
        model.record(.miss, for: first, sheet: InkSheet())
        #expect(model.progress.days[model.today]?.written == 1)
        #expect(model.progress.states[first]?.lastGrade == .good)
    }

    @Test func freeUsersPracticeOnlyTheFreePack() {
        let model = makeModel()
        #expect(!model.isPro)
        model.setPack(.yoji, enabled: true)
        #expect(model.activePacks == [.basic])
        #expect(model.showPaywall)
        #expect(!model.dailyCountChoices.contains(20))
    }

    @Test func freeUsersSeeTheLatestThirtyInkSheets() {
        let store = FakeStore()
        var progress = Progress()
        let base = Day(Date(timeIntervalSinceReferenceDate: 815_000_000))
        for (i, word) in WordBook.words(in: .basic).prefix(40).enumerated() {
            var state = CardState(due: base)
            state.apply(.good, on: base.adding(-40 + i))
            progress.states[word.id] = state
        }
        store.progress = progress
        let model = makeModel(store: store)
        let ids = model.notebookWordIDs
        #expect(ids.count == 40)
        #expect(model.isInkVisible(ids[0]))
        #expect(model.isInkVisible(ids[29]))
        #expect(!model.isInkVisible(ids[30]))
    }

    @Test func changingTheDailyCountRebuildsAnUntouchedPlan() {
        let model = makeModel()
        model.ensureTodayPlan()
        model.setDailyCount(5)
        #expect(model.todayPlan.wordIDs.count == 5)
        model.setDailyCount(20)  // 無料では選べない
        #expect(model.progress.dailyCount == 5)
    }

    @Test func extendingTodayAddsNewWords() {
        let model = makeModel()
        let before = model.todayPlan.wordIDs
        for id in before { model.record(.good, for: id, sheet: InkSheet()) }
        #expect(model.todayPlan.isDone)
        model.extendToday()
        #expect(model.todayPlan.wordIDs.count == before.count + 5)
        #expect(!model.todayPlan.isDone)
    }
}
