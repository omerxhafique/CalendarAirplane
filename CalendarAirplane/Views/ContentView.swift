import SwiftUI

struct ContentView: View {
    @ObservedObject private var auth = GoogleAuthService.shared
    @ObservedObject private var scheduler = MeetingAlertScheduler.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Calendar Airplane")
                .font(.title.bold())

            Text("Flies a banner across your screen when a Google Calendar meeting is coming up.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label(auth.isSignedIn ? (auth.userEmail ?? "Signed in") : "Not signed in", systemImage: auth.isSignedIn ? "checkmark.circle.fill" : "person.crop.circle.badge.exclamationmark")
                    if scheduler.isPolling {
                        Label("Watching calendar (every 60s)", systemImage: "calendar.badge.clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let status = scheduler.statusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Open Settings…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                Button("Demo View") {
                    scheduler.triggerTestFlight()
                }
                .keyboardShortcut("t", modifiers: [.command])
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            if auth.isSignedIn {
                scheduler.start()
            }
        }
    }
}
