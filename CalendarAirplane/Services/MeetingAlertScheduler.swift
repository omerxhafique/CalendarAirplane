import Foundation
import SwiftUI

@MainActor
final class MeetingAlertScheduler: ObservableObject {
    static let shared = MeetingAlertScheduler()

    @AppStorage("leadTimeMinutes") var leadTimeMinutes = 10
    @AppStorage("alertsEnabled") var alertsEnabled = true
    @AppStorage("alertedEventKeys") private var alertedKeysStorage = ""

    @Published private(set) var isPolling = false
    @Published var statusMessage: String?

    private let calendarService = CalendarSyncService()
    private var pollTask: Task<Void, Never>?
    private struct FlyoverPayload {
        let title: String
        let subtitle: String?
        let timeRange: String?
    }

    private var animationQueue: [FlyoverPayload] = []
    private var isPlayingAnimation = false

    private var alertedKeys: Set<String> {
        get {
            guard !alertedKeysStorage.isEmpty else { return [] }
            return Set(alertedKeysStorage.split(separator: "\n").map(String.init))
        }
        set { alertedKeysStorage = newValue.sorted().joined(separator: "\n") }
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { await pollLoop() }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }

    func triggerTestFlight(title: String = "Team sync — starting soon") {
        let start = Date().addingTimeInterval(5 * 60)
        let end = start.addingTimeInterval(30 * 60)
        let range = "\(TodayAgendaStore.formatTime(start)) – \(TodayAgendaStore.formatTime(end))"
        enqueueAnimation(title: title, subtitle: "Preview", timeRange: range)
    }

    private func pollLoop() async {
        isPolling = true
        while !Task.isCancelled {
            await tick()
            try? await Task.sleep(for: .seconds(60))
        }
        isPolling = false
    }

    private static let fixedFiveMinuteLead = 5
    private static let pollIntervalSeconds: TimeInterval = 60
    /// Half-open window around each alert offset (tuned for 60s polling).
    private static let alertWindowPadding: TimeInterval = 60

    private enum AlertPhase: String {
        case lead
        case fiveMinute = "5min"
        case start
    }

    private func tick() async {
        guard alertsEnabled else { return }
        guard GoogleAuthService.shared.isSignedIn else { return }

        let lead = max(1, leadTimeMinutes)
        let now = Date()
        let fetchHorizonMinutes = max(lead, Self.fixedFiveMinuteLead)
        let fetchStart = now.addingTimeInterval(-Self.alertWindowPadding)
        let fetchEnd = now.addingTimeInterval(TimeInterval(fetchHorizonMinutes * 60) + Self.alertWindowPadding)

        do {
            let token = try await GoogleAuthService.shared.getValidAccessToken()
            let events = try await calendarService.fetchEvents(from: fetchStart, to: fetchEnd, accessToken: token)

            for event in events {
                let secondsUntil = event.startDate.timeIntervalSince(now)
                let range = TodayAgendaStore.formatTimeRange(for: event)

                if shouldFireLeadAlert(secondsUntil: secondsUntil, leadMinutes: lead),
                   !hasAlerted(event: event, phase: .lead) {
                    markAlerted(event: event, phase: .lead)
                    enqueueAnimation(
                        title: event.title,
                        subtitle: subtitle(for: .lead, leadMinutes: lead),
                        timeRange: range
                    )
                }

                if shouldFireFiveMinuteAlert(secondsUntil: secondsUntil, leadMinutes: lead),
                   !hasAlerted(event: event, phase: .fiveMinute) {
                    markAlerted(event: event, phase: .fiveMinute)
                    enqueueAnimation(
                        title: event.title,
                        subtitle: subtitle(for: .fiveMinute, leadMinutes: lead),
                        timeRange: range
                    )
                }

                if shouldFireStartAlert(secondsUntil: secondsUntil),
                   !hasAlerted(event: event, phase: .start) {
                    markAlerted(event: event, phase: .start)
                    enqueueAnimation(
                        title: event.title,
                        subtitle: subtitle(for: .start, leadMinutes: lead),
                        timeRange: range
                    )
                }
            }
            statusMessage = nil
        } catch CalendarError.unauthorized {
            GoogleAuthService.shared.signOut()
            statusMessage = CalendarError.unauthorized.localizedDescription
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func shouldFireLeadAlert(secondsUntil: TimeInterval, leadMinutes: Int) -> Bool {
        isWithinAlertWindow(secondsUntil: secondsUntil, minutesBeforeStart: leadMinutes)
    }

    private func shouldFireFiveMinuteAlert(secondsUntil: TimeInterval, leadMinutes: Int) -> Bool {
        guard leadMinutes != Self.fixedFiveMinuteLead else { return false }
        return isWithinAlertWindow(secondsUntil: secondsUntil, minutesBeforeStart: Self.fixedFiveMinuteLead)
    }

    private func shouldFireStartAlert(secondsUntil: TimeInterval) -> Bool {
        secondsUntil <= Self.alertWindowPadding && secondsUntil >= -Self.alertWindowPadding
    }

    private func isWithinAlertWindow(secondsUntil: TimeInterval, minutesBeforeStart: Int) -> Bool {
        let target = TimeInterval(minutesBeforeStart * 60)
        let lower = max(0, target - Self.pollIntervalSeconds)
        let upper = target + Self.alertWindowPadding
        return secondsUntil > lower && secondsUntil <= upper
    }

    private func alertKey(event: CalendarEvent, phase: AlertPhase) -> String {
        "\(event.dedupeKey)|\(phase.rawValue)"
    }

    private func hasAlerted(event: CalendarEvent, phase: AlertPhase) -> Bool {
        alertedKeys.contains(alertKey(event: event, phase: phase))
    }

    private func markAlerted(event: CalendarEvent, phase: AlertPhase) {
        markAlerted(alertKey(event: event, phase: phase))
    }

    private func subtitle(for phase: AlertPhase, leadMinutes: Int) -> String {
        switch phase {
        case .lead:
            return "In \(leadMinutes) minutes"
        case .fiveMinute:
            return "In 5 minutes"
        case .start:
            return "Starting now"
        }
    }

    private func markAlerted(_ key: String) {
        var keys = alertedKeys
        keys.insert(key)
        if keys.count > 200 {
            keys = Set(keys.suffix(100))
        }
        alertedKeys = keys
    }

    private func enqueueAnimation(title: String, subtitle: String?, timeRange: String?) {
        animationQueue.append(FlyoverPayload(title: title, subtitle: subtitle, timeRange: timeRange))
        processQueue()
    }

    private func processQueue() {
        guard !isPlayingAnimation, !animationQueue.isEmpty else { return }
        isPlayingAnimation = true
        let payload = animationQueue.removeFirst()
        OverlayWindowController.shared.playFlight(
            meetingTitle: payload.title,
            subtitle: payload.subtitle,
            timeRange: payload.timeRange
        ) { [weak self] in
            Task { @MainActor in
                self?.isPlayingAnimation = false
                self?.processQueue()
            }
        }
    }
}
