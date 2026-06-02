import SwiftUI

struct ContentView: View {
    @Environment(\.openSettings) private var openSettings

    @ObservedObject private var auth = GoogleAuthService.shared
    @ObservedObject private var scheduler = MeetingAlertScheduler.shared
    @ObservedObject private var todayAgenda = TodayAgendaStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBar
            Divider()
            scrollArea
            Divider()
            bottomBar
        }
        .frame(minWidth: 360, maxWidth: 360, minHeight: 280)
        .background {
            ZStack {
                Color(red: 0.99, green: 0.97, blue: 0.98)
                AppTheme.windowBackground
            }
        }
        .tint(AppTheme.pinkDeep)
        .preferredColorScheme(.light)
        .onAppear {
            if auth.isSignedIn {
                scheduler.start()
            }
        }
        .task(id: auth.isSignedIn) {
            await runTodayRefreshLoop()
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn { scheduler.start() }
            else { scheduler.stop(); todayAgenda.clear() }
        }
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack(spacing: 10) {
            Image("FlyoverPlane")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 20)

            Text("Calendar Airplane")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)

            Spacer()

            statusDot
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusDot: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(auth.isSignedIn ? AppTheme.pinkDeep : AppTheme.inkMuted.opacity(0.4))
                .frame(width: 7, height: 7)
            Text(auth.isSignedIn ? (auth.userEmail ?? "Connected") : "Not signed in")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.inkMuted)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 140, alignment: .leading)
        }
    }

    // MARK: - Scroll area

    private var scrollArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !auth.isSignedIn {
                    signInPrompt
                } else {
                    todayList
                }

                if let err = auth.lastError, !auth.isSignedIn {
                    Text(err)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.red.opacity(0.85))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
        }
        .frame(maxHeight: 400)
    }

    private var signInPrompt: some View {
        VStack(spacing: 14) {
            Text("Sign in to see your meetings and get flyover alerts before they start.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(AppTheme.inkMuted)
                .multilineTextAlignment(.center)

            Button("Sign in with Google") { auth.signIn() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!GoogleOAuthConfig.isConfigured)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Today")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if todayAgenda.isLoading {
                    ProgressView().controlSize(.mini)
                } else {
                    Button("Refresh") { Task { await todayAgenda.refresh() } }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.pinkDeep)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if let err = todayAgenda.errorMessage {
                Text(err)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            } else if todayAgenda.events.isEmpty, !todayAgenda.isLoading {
                Text("No meetings today.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.inkMuted)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(todayAgenda.events) { event in
                        eventRow(event)
                        if event.id != todayAgenda.events.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }

            if scheduler.isPolling {
                Label("Watching · every 60s", systemImage: "calendar")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.inkMuted.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            if let status = scheduler.statusMessage {
                Text(status)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(TodayAgendaStore.formatTimeRange(for: event))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.pinkDeep)
                .frame(width: 110, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)

                if let notes = event.notes {
                    Text(notes)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.inkMuted)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button("Demo flight") { scheduler.triggerTestFlight() }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut("t", modifiers: [.command])

            Spacer()

            Button("Settings") { openSettings() }
                .buttonStyle(SecondaryButtonStyle())

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func runTodayRefreshLoop() async {
        guard auth.isSignedIn else { return }
        await todayAgenda.refresh()
        while !Task.isCancelled, auth.isSignedIn {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled, auth.isSignedIn else { break }
            await todayAgenda.refresh()
        }
    }
}

#Preview {
    ContentView()
}
