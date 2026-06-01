import SwiftUI

struct SettingsView: View {
    @ObservedObject private var auth = GoogleAuthService.shared
    @ObservedObject private var scheduler = MeetingAlertScheduler.shared

    @AppStorage("leadTimeMinutes") private var leadTimeMinutes = 10
    @AppStorage("alertsEnabled") private var alertsEnabled = true

    @ObservedObject private var launchAtLogin = LaunchAtLoginController.shared

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open at login", isOn: launchAtLoginBinding)
                if launchAtLogin.needsApproval {
                    Text("Turn on Calendar Airplane in System Settings → General → Login Items & Extensions.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let err = launchAtLogin.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Alerts") {
                Toggle("Enable meeting flyover", isOn: $alertsEnabled)
                Stepper(value: $leadTimeMinutes, in: 1 ... 120, step: 1) {
                    Text("Lead time: \(leadTimeMinutes) min before start")
                }
            }

            Section("Google Calendar") {
                if !GoogleOAuthConfig.isConfigured {
                    Text("Add your Desktop OAuth Client ID as `GOOGLE_CLIENT_ID` in Info.plist, and register redirect URI `\(GoogleOAuthConfig.redirectURI)` in Google Cloud Console.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if auth.isSignedIn {
                    LabeledContent("Account", value: auth.userEmail ?? "Connected")
                    Button("Sign out") {
                        auth.signOut()
                        scheduler.stop()
                    }
                } else {
                    Button("Sign in with Google") {
                        auth.signIn()
                    }
                    .disabled(!GoogleOAuthConfig.isConfigured)
                }
                if let err = auth.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Preview") {
                Button("Demo View") {
                    scheduler.triggerTestFlight()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
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

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }
}
