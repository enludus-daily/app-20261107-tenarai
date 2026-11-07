import UIKit
import SwiftUI
import UserNotifications

/// 毎日のお知らせ（端末の中だけの通知）
enum Reminder {
    static let id = "tenarai.daily"

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 許可を求め、毎日その時刻に 1 回だけ知らせる。許可されなければ false
    static func schedule(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "手習い帖"
        content.body = "今日の字が待っています。1 字だけでも。"
        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let request = UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))
        try? await center.add(request)
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) var model
    @Environment(\.openURL) var openURL
    @AppStorage("tenarai.reminderOn") var reminderOn = false
    @AppStorage("tenarai.reminderMinutes") var reminderMinutes = 21 * 60
    @State var denied = false
    @State var restoring = false
    @State var restoreMessage: String?

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Picker("1 日の字の数", selection: Binding(get: { model.progress.dailyCount }, set: { model.setDailyCount($0) })) {
                        ForEach(model.dailyCountChoices, id: \.self) { Text("\($0) 字").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if !model.isPro {
                        proHint("1 日 20 字は Pro")
                    }
                } header: {
                    header("稽古")
                }

                Section {
                    ForEach(Pack.all) { pack in
                        let locked = !pack.isFree && !model.isPro
                        Toggle(isOn: Binding(
                            get: { !locked && model.progress.enabledPacks.contains(pack.id) },
                            set: { model.setPack(pack.id, enabled: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(pack.title).font(Typo.body)
                                    if locked { Image(systemName: "lock").font(.caption2).foregroundStyle(Palette.fujiDeep) }
                                }
                                Text("\(WordBook.words(in: pack.id).count) 語・\(pack.summary)")
                                    .font(Typo.small).foregroundStyle(Palette.sub)
                            }
                        }
                        .tint(Palette.fujiDeep)
                    }
                } header: {
                    header("稽古する束")
                }

                Section {
                    Toggle("毎日のお知らせ", isOn: $reminderOn).tint(Palette.fujiDeep)
                    if reminderOn {
                        DatePicker("時刻", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                    if denied {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("通知が許可されていません。設定アプリで「手習い帖」の通知をオンにすると、毎日お知らせします。")
                                .font(Typo.small).foregroundStyle(Palette.sub)
                            Button("設定を開く") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            .font(Typo.small)
                        }
                    }
                    Toggle("振動", isOn: $model.hapticsOn).tint(Palette.fujiDeep)
                    Button("使い方をもう一度見る") { model.replayOnboarding() }
                } header: {
                    header("お知らせと手応え")
                }

                Section {
                    if model.isPro {
                        Label("Pro を使っています。ありがとうございます。", systemImage: "checkmark.seal")
                            .foregroundStyle(Palette.fujiDeep)
                    } else {
                        Button("Pro でできること") { model.showPaywall = true }
                    }
                    Button(restoring ? "確かめています…" : "購入を復元") {
                        restoring = true
                        Task {
                            await model.purchases.restore()
                            restoring = false
                            restoreMessage = model.isPro ? "Pro を復元しました。" : "復元できる購入は見つかりませんでした。"
                        }
                    }
                    .disabled(restoring)
                    if let restoreMessage {
                        Text(restoreMessage).font(Typo.small).foregroundStyle(Palette.sub)
                    }
                } header: {
                    header("Pro")
                }

                Section {
                    Text("書いた字・丸・暦は、この iPhone の中だけに保存します。どこにも送りません。広告・解析・アカウントはありません。アプリを削除すると記録も消えます。")
                        .font(Typo.small).foregroundStyle(Palette.sub)
                    Text("版 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(Typo.small).foregroundStyle(Palette.sub)
                } header: {
                    header("プライバシー")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.ground)
            .navigationTitle("設定")
            .onChange(of: reminderOn) { _, on in on ? scheduleReminder() : Reminder.cancel() }
            .onChange(of: reminderMinutes) { _, _ in if reminderOn { scheduleReminder() } }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date() },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                reminderMinutes = (parts.hour ?? 21) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func scheduleReminder() {
        Task {
            let ok = await Reminder.schedule(hour: reminderMinutes / 60, minute: reminderMinutes % 60)
            denied = !ok
            if !ok { reminderOn = false }
        }
    }

    private func header(_ text: String) -> some View {
        HStack(spacing: 6) {
            GridCell().frame(width: 12, height: 12)
            Text(text).font(Typo.label).kerning(0.6)
        }
        .foregroundStyle(Palette.sub)
    }

    private func proHint(_ text: String) -> some View {
        Button { model.showPaywall = true } label: {
            Label(text, systemImage: "lock").font(Typo.small)
        }
        .foregroundStyle(Palette.fujiDeep)
    }
}
