import SwiftUI

@main
struct CalendarAirplaneApp: App {
    init() {
        Task { @MainActor in
            LaunchAtLoginController.shared.refresh()
            if GoogleAuthService.shared.isSignedIn {
                MeetingAlertScheduler.shared.start()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Settings {
            SettingsView()
        }
    }
}
