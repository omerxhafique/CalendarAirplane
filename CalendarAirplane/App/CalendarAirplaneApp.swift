import SwiftUI

@main
struct CalendarAirplaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Task { @MainActor in
            LaunchAtLoginController.shared.refresh()
            if GoogleAuthService.shared.isSignedIn {
                MeetingAlertScheduler.shared.start()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra("Calendar Airplane", systemImage: "airplane") {
            ContentView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
