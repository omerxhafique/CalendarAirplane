import SwiftUI

struct SettingsView: View {
    @ObservedObject private var auth = GoogleAuthService.shared
    @ObservedObject private var scheduler = MeetingAlertScheduler.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginController.shared

    @AppStorage("leadTimeMinutes") private var leadTimeMinutes = 10
    @AppStorage("alertsEnabled") private var alertsEnabled = true
    @AppStorage("flyoverDurationSeconds") private var flyoverDurationSeconds = 20.0

    var body: some View {
        ZStack {
            AppTheme.windowBackground
                .ignoresSafeArea()

            Form {
                Section {
                    Toggle("Open at login", isOn: launchAtLoginBinding)
                    loginItemNote
                } header: {
                    sectionHeader("Startup")
                }

                Section {
                    Toggle("Meeting flyover", isOn: $alertsEnabled)
                    Stepper(value: $leadTimeMinutes, in: 1 ... 120, step: 1) {
                        Text("\(leadTimeMinutes) min before start")
                    }
                } header: {
                    sectionHeader("Alerts")
                }

                Section {
                    oauthNote
                    accountRow
                    authErrorNote
                } header: {
                    sectionHeader("Google Calendar")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Flyover speed")
                            Spacer()
                            Text(flyoverSpeedLabel)
                                .foregroundStyle(AppTheme.ink.opacity(0.75))
                        }
                        Slider(value: $flyoverDurationSeconds, in: 8 ... 45, step: 1)
                    }
                    noteText("Lower seconds = faster flight across the screen.")

                    Button("Demo flight") {
                        scheduler.triggerTestFlight()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    sectionHeader("Preview")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.ink)
            .padding(20)
        }
        .frame(width: 480)
        .frame(minHeight: 420)
        .preferredColorScheme(.light)
        .tint(AppTheme.pinkDeep)
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn {
                scheduler.start()
            } else {
                scheduler.stop()
            }
        }
        .onAppear {
            launchAtLogin.refresh()
            if auth.isSignedIn {
                scheduler.start()
            }
        }
    }

    @ViewBuilder
    private var loginItemNote: some View {
        if launchAtLogin.needsApproval {
            noteText("Allow Calendar Airplane in System Settings → Login Items.")
        }
        if let err = launchAtLogin.lastError {
            noteText(err, color: .red.opacity(0.85))
        }
    }

    @ViewBuilder
    private var oauthNote: some View {
        if !GoogleOAuthConfig.isConfigured {
            noteText("Add credentials in GoogleOAuth.local.plist (see README).")
        }
    }

    @ViewBuilder
    private var accountRow: some View {
        if auth.isSignedIn {
            LabeledContent("Signed in as") {
                Text(auth.userEmail ?? "Connected")
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button("Sign out", role: .destructive) {
                auth.signOut()
                scheduler.stop()
            }
        } else {
            Button("Sign in with Google") {
                auth.signIn()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!GoogleOAuthConfig.isConfigured)
        }
    }

    @ViewBuilder
    private var authErrorNote: some View {
        if let err = auth.lastError {
            noteText(err, color: .red.opacity(0.85))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.ink)
            .tracking(0.6)
    }

    private func noteText(_ text: String, color: Color = AppTheme.ink.opacity(0.75)) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(color)
    }

    private var flyoverSpeedLabel: String {
        let seconds = Int(min(max(flyoverDurationSeconds, 8), 45))
        if seconds <= 12 { return "Fast · \(seconds)s" }
        if seconds >= 32 { return "Slow · \(seconds)s" }
        return "Normal · \(seconds)s"
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }
}

#Preview {
    SettingsView()
}
