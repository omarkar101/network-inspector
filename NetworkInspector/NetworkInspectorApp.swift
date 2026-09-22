import SwiftUI

@main
struct NetworkInspectorApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var model = LiveTrafficModel()
    @State private var internetAccess = InternetAccessController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Apps", systemImage: "square.stack.3d.up.fill") {
                AppStatsDashboardView(model: model, internetAccess: internetAccess)
            }
            Tab("Requests", systemImage: "list.bullet.rectangle.portrait") {
                NavigationStack {
                    RequestListView(title: "Requests", entries: model.entries, showsApp: true)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task { await model.run() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Also catches the filter being turned off in Settings meanwhile.
            if phase == .active {
                Task { await internetAccess.refresh() }
            }
        }
        .onChange(of: internetAccess.blocklist, initial: true) { _, blocklist in
            model.blocklist = blocklist
        }
    }
}

#Preview {
    RootView()
}
