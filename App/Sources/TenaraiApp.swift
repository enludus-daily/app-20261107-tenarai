import SwiftUI

@main
struct TenaraiApp: App {
    @State var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // 半紙と墨の世界観を保つため、ライトに固定する（StudyReel と同じ判断）
                .preferredColorScheme(.light)
                .tint(Palette.fujiDeep)
                .task { await model.purchases.load() }
        }
    }
}

/// 今日の稽古・手習い帖・設定。iPhone Duo の内側（regular）では TabView がサイドバーにもなる
struct RootView: View {
    @Environment(AppModel.self) var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.onboardingDone {
                TabView(selection: $model.tab) {
                    Tab("今日の稽古", systemImage: "square.and.pencil", value: AppTab.today) { TodayView() }
                    Tab("手習い帖", systemImage: "book.closed", value: AppTab.notebook) { NotebookView() }
                    Tab("設定", systemImage: "gearshape", value: AppTab.settings) { SettingsView() }
                }
                .tabViewStyle(.sidebarAdaptable)
                .transition(.opacity)
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .sheet(isPresented: $model.showPaywall) {
            PaywallView().presentationBackground(Palette.ground)
        }
    }
}
