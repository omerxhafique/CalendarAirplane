import SwiftUI

struct ContentView: View {
    @Environment(\.openSettings) private var openSettings

    @ObservedObject private var auth = GoogleAuthService.shared
    @ObservedObject private var scheduler = MeetingAlertScheduler.shared
    @ObservedObject private var todayAgenda = TodayAgendaStore.shared

    var body: some View {
        ZStack {
            AppTheme.windowBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 24)

                statusCard
                    .padding(.bottom, 16)

                if auth.isSignedIn {
                    todayMeetingsCard
                        .padding(.bottom, 16)
                }

                if let err = auth.lastError, !auth.isSignedIn {
                    Text(err)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(.bottom, 12)
                }

                actionRow

                Spacer(minLength: 0)
            }
            .padding(28)
        }
        .frame(minWidth: 440, minHeight: 420)
        .tint(AppTheme.pinkDeep)
        .task(id: auth.isSignedIn) {
            await runTodayRefreshLoop()
        }
        .onAppear {
            if auth.isSignedIn {
                scheduler.start()
            }
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn {
                scheduler.start()
            } else {
                scheduler.stop()
                todayAgenda.clear()
            }
        }
    }

    private func runTodayRefreshLoop() async {
        guard auth.isSignedIn else { return }
        await todayAgenda.refresh()
        while !Task.isCancelled, auth.isSignedIn {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled, auth.isSignedIn else { break }
            await todayAgenda.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("FlyoverPlane")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text("Calendar Airplane")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)

                Text("A gentle flyover before your meetings.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(auth.isSignedIn ? AppTheme.pinkDeep : AppTheme.inkMuted.opacity(0.35))
                    .frame(width: 8, height: 8)

                Text(auth.isSignedIn ? (auth.userEmail ?? "Connected") : "Not signed in")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if auth.isSignedIn, scheduler.isPolling {
                Label("Watching calendar · every 60s", systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.inkMuted)
            }

            if let status = scheduler.statusMessage {
                Text(status)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var todayMeetingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                if todayAgenda.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Refresh") {
                        Task { await todayAgenda.refresh() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.pinkDeep)
                }
            }

            if let err = todayAgenda.errorMessage {
                Text(err)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)
            } else if todayAgenda.events.isEmpty, !todayAgenda.isLoading {
                Text("No meetings on your calendar today.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.inkMuted)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(todayAgenda.events) { event in
                            HStack(alignment: .top, spacing: 12) {
                                Text(TodayAgendaStore.formatTimeRange(for: event))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.pinkDeep)
                                    .frame(width: 118, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(AppTheme.ink)
                                        .lineLimit(3)

                                    if let notes = event.notes {
                                        Text(notes)
                                            .font(.system(size: 12, weight: .regular, design: .rounded))
                                            .foregroundStyle(AppTheme.inkMuted)
                                            .lineLimit(5)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if auth.isSignedIn {
                Button("Settings") {
                    openSettings()
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("Sign in with Google") {
                    auth.signIn()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!GoogleOAuthConfig.isConfigured)
            }

            Button("Demo flight") {
                scheduler.triggerTestFlight()
            }
            .buttonStyle(SecondaryButtonStyle())
            .keyboardShortcut("t", modifiers: [.command])
        }
    }
}

#Preview {
    ContentView()
}
