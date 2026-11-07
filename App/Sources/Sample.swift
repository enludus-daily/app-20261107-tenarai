import Foundation

/// スクリーンショット用の見本の記録（起動引数 -screenshotScene <名前> のときだけ。保存はしない）
@MainActor
enum Sample {
    static func fill(_ model: AppModel, scene: String) {
        let today = model.today
        switch scene {
        case "empty":
            model.tab = .notebook
            return
        case "notebook", "word", "weak":
            model.tab = .notebook
        case "settings":
            model.tab = .settings
        default:
            model.tab = .today
        }

        var progress = PracticeLog()
        let words = WordBook.words(in: .basic)
        // 45 日ぶんの稽古（ところどころ休み）
        var stateIndex = 0
        for offset in stride(from: 45, through: 1, by: -1) {
            let day = today.adding(-offset)
            if [3, 9, 10, 17, 24, 31, 32, 38].contains(offset) { continue }
            let written = [4, 10, 10, 12, 6, 10, 15, 10][offset % 8]
            progress.days[day] = DayRecord(written: written, good: written * 2 / 3)
            if stateIndex < 70 {
                let word = words[stateIndex]
                var state = CardState(due: day)
                state.apply(.good, on: day)
                if offset % 5 == 0 { state.apply(.miss, on: day) }
                if offset % 3 == 0 { state.apply(.good, on: day); state.apply(.good, on: day); state.apply(.good, on: day) }
                progress.states[word.id] = state
                stateIndex += 1
            }
        }
        // 苦手（2 回書けなかった）
        for id in ["齟齬", "躊躇", "憂鬱"] {
            var state = progress.states[id] ?? CardState(due: today)
            state.apply(.miss, on: today.adding(-2))
            state.apply(.miss, on: today.adding(-1))
            progress.states[id] = state
        }

        var plan = Scheduler.plan(day: today, count: 10, states: progress.states, words: words)
        let finished: Int
        switch scene {
        case "done", "paywall": finished = plan.wordIDs.count
        case "launch", "notebook", "word", "weak", "settings", "pro": finished = 0
        default: finished = 3
        }
        let grades: [Grade] = [.good, .almost, .good, .miss, .good, .good, .almost, .good, .good, .good]
        for (i, id) in plan.wordIDs.prefix(finished).enumerated() {
            plan.results[id] = grades[i % grades.count]
            var state = progress.states[id] ?? CardState(due: today)
            state.apply(grades[i % grades.count], on: today)
            progress.states[id] = state
        }
        if finished > 0 {
            progress.days[today] = DayRecord(written: finished, good: plan.goodCount)
        }
        progress.plan = plan
        model.replaceForSample(progress: progress, ink: [:])
        if scene == "paywall" { model.showPaywall = true }
    }
}
