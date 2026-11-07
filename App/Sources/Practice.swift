import Foundation

/// 日付を「日」の通し番号で持つ（端末の暦の 1 日の始まりで区切る）
struct Day: Hashable, Comparable, Codable, Sendable {
    let index: Int

    init(_ index: Int) { self.index = index }

    init(_ date: Date, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: date)
        let reference = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        index = calendar.dateComponents([.day], from: reference, to: start).day ?? 0
    }

    func adding(_ days: Int) -> Day { Day(index + days) }
    func date(calendar: Calendar = .current) -> Date {
        let reference = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        return calendar.date(byAdding: .day, value: index, to: reference) ?? reference
    }

    static func < (lhs: Day, rhs: Day) -> Bool { lhs.index < rhs.index }
}

/// 自分でつける丸
enum Grade: String, Codable, CaseIterable, Sendable {
    /// 書けた（はなまる）
    case good
    /// 惜しい（△）
    case almost
    /// 書けなかった（・）
    case miss

    var label: String {
        switch self {
        case .good: return "書けた"
        case .almost: return "惜しい"
        case .miss: return "書けなかった"
        }
    }
}

/// 1 語の覚え具合（間隔をあけて戻ってくる）
struct CardState: Codable, Equatable, Sendable {
    /// 0 = まだ書けない。上がるほど間隔が開く
    var level: Int = 0
    var due: Day
    var reviews: Int = 0
    var misses: Int = 0
    var lastGrade: Grade?
    var lastDay: Day?

    /// 書けた → 次に戻ってくるまでの日数（段ごと）
    static let intervals = [1, 3, 7, 14, 30, 60]
    /// この段から「書ける字」に数える（7 日あけて書けた）
    static let masteredLevel = 4

    var isMastered: Bool { level >= Self.masteredLevel }
    /// 苦手：最後に書けなかった、または 2 回以上書けなかった
    var isWeak: Bool { lastGrade == .miss || (misses >= 2 && level < Self.masteredLevel) }

    mutating func apply(_ grade: Grade, on day: Day) {
        reviews += 1
        lastGrade = grade
        lastDay = day
        switch grade {
        case .good:
            level = min(level + 1, Self.intervals.count)
            due = day.adding(Self.intervals[level - 1])
        case .almost:
            // 段は下げず、明日もう一度
            due = day.adding(1)
        case .miss:
            misses += 1
            level = 0
            due = day.adding(1)
        }
    }
}

/// 1 日の稽古
struct DayPlan: Codable, Equatable, Sendable {
    let day: Day
    var wordIDs: [String]
    var results: [String: Grade] = [:]
    var reviewCount: Int
    var weakOnly: Bool = false

    var isDone: Bool { !wordIDs.isEmpty && results.count >= wordIDs.count }
    var nextWordID: String? { wordIDs.first { results[$0] == nil } }
    var position: Int { min(results.count, wordIDs.count) }
    var goodCount: Int { results.values.filter { $0 == .good }.count }
    var newCount: Int { wordIDs.count - reviewCount }
}

enum Scheduler {
    /// 今日の稽古を作る。戻ってきた字（期日が来たもの）を先に、残りを新しい字で埋める。
    static func plan(
        day: Day,
        count: Int,
        states: [String: CardState],
        words: [Word],
        weakOnly: Bool = false
    ) -> DayPlan {
        let available = Set(words.map(\.id))
        if weakOnly {
            let weak = states
                .filter { available.contains($0.key) && $0.value.isWeak }
                .sorted { ($0.value.misses, $1.value.due) > ($1.value.misses, $0.value.due) }
                .prefix(count)
                .map(\.key)
            return DayPlan(day: day, wordIDs: Array(weak), reviewCount: weak.count, weakOnly: true)
        }
        let due = states
            .filter { available.contains($0.key) && $0.value.due <= day }
            .sorted { lhs, rhs in
                if lhs.value.due != rhs.value.due { return lhs.value.due < rhs.value.due }
                if lhs.value.misses != rhs.value.misses { return lhs.value.misses > rhs.value.misses }
                return lhs.key < rhs.key
            }
            .prefix(count)
            .map(\.key)
        let fresh = words
            .filter { states[$0.id] == nil }
            .prefix(max(0, count - due.count))
            .map(\.id)
        return DayPlan(day: day, wordIDs: due + fresh, reviewCount: due.count)
    }

    /// 明日、戻ってくる字の数
    static func dueCount(on day: Day, states: [String: CardState], available: Set<String>) -> Int {
        states.filter { available.contains($0.key) && $0.value.due <= day }.count
    }
}

/// 稽古した日の記録
struct DayRecord: Codable, Equatable, Sendable {
    var written: Int = 0
    var good: Int = 0
}

enum Streak {
    /// 今日（まだなら昨日）から、続けて稽古した日数
    static func current(days: Set<Day>, today: Day) -> Int {
        var cursor = days.contains(today) ? today : today.adding(-1)
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = cursor.adding(-1)
        }
        return count
    }

    /// 暦のマスの濃さ（0〜3）。最大値ではなく決まった区切りで決める（StudyReel の暦と同じ考え方）
    static func level(written: Int) -> Int {
        switch written {
        case 0: return 0
        case 1...4: return 1
        case 5...9: return 2
        default: return 3
        }
    }
}
