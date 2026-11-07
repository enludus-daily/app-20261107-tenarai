import Foundation

/// 稽古する語。ID は語そのもの（全部の束で重ならないことをテストで確かめる）
struct Word: Identifiable, Hashable, Sendable {
    let text: String
    let reading: String
    /// 例文。`{}` が空欄
    let sentence: String
    let pack: Pack.ID

    var id: String { text }
    var characters: [String] { text.map(String.init) }

    /// 空欄の前・後ろ
    var sentenceParts: (before: String, after: String) {
        let parts = sentence.components(separatedBy: "{}")
        return (parts.first ?? "", parts.count > 1 ? parts[1] : "")
    }

    /// 空欄に語を入れた例文
    var filledSentence: String { sentence.replacingOccurrences(of: "{}", with: text) }
}

/// 語の束
struct Pack: Identifiable, Hashable, Sendable {
    enum ID: String, CaseIterable, Codable, Sendable {
        case basic, season, letter, yoji, nansho
    }

    let id: ID
    let title: String
    let summary: String
    let isFree: Bool

    static let all: [Pack] = [
        Pack(id: .basic, title: "読めるのに書けない", summary: "憂鬱・曖昧・挨拶… 毎日の言葉で、いざ書くと手が止まる字", isFree: true),
        Pack(id: .season, title: "季節と暮らし", summary: "時雨・氷柱・注連縄… 季節の手紙や献立に出てくる字", isFree: false),
        Pack(id: .letter, title: "手紙と仕事", summary: "拝啓・御中・査収… 一筆箋や送り状で恥をかかない字", isFree: false),
        Pack(id: .yoji, title: "四字熟語", summary: "紆余曲折・臥薪嘗胆… 4 マスを埋める手応えの束", isFree: false),
        Pack(id: .nansho, title: "難書の字", summary: "薔薇・檸檬・顰蹙… 書けたら少し自慢できる字", isFree: false),
    ]

    static func pack(_ id: ID) -> Pack { all.first { $0.id == id }! }
}

enum WordBook {
    /// すべての語（束の順、束の中は用意した順）
    static let all: [Word] = Pack.ID.allCases.flatMap { id in parse(WordData.raw[id] ?? "", pack: id) }
    static let byID: [String: Word] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    static func words(in pack: Pack.ID) -> [Word] { all.filter { $0.pack == pack } }
    static func word(_ id: String) -> Word? { byID[id] }

    /// 1 行 = `語|よみ|例文`。空行と # の行は飛ばす
    static func parse(_ raw: String, pack: Pack.ID) -> [Word] {
        raw.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            let cols = trimmed.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard cols.count == 3 else { return nil }
            return Word(text: cols[0], reading: cols[1], sentence: cols[2], pack: pack)
        }
    }
}
