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
        enqueueAnimation(title: title, timeRange: range, dedupeKey: nil)
    }

    private func pollLoop() async {
        isPolling = true
        while !Task.isCancelled {
            await tick()
            try? await Task.sleep(for: .seconds(60))
        }
        isPolling = false
    }

    private func tick() async {
        guard alertsEnabled else { return }
        guard GoogleAuthService.shared.isSignedIn else { return }

        let lead = max(1, leadTimeMinutes)
        let now = Date()
        let windowEnd = now.addingTimeInterval(TimeInterval(lead * 60))

        do {
            let token = try await GoogleAuthService.shared.getValidAccessToken()
            let events = try await calendarService.fetchEvents(from: now, to: windowEnd, accessToken: token)

            for event in events {
                let secondsUntil = event.startDate.timeIntervalSince(now)
                guard secondsUntil > 0, secondsUntil <= TimeInterval(lead * 60) else { continue }
                guard !alertedKeys.contains(event.dedupeKey) else { continue }
                markAlerted(event.dedupeKey)
                let range = TodayAgendaStore.formatTimeRange(for: event)
                enqueueAnimation(title: event.title, timeRange: range, dedupeKey: event.dedupeKey)
            }
            statusMessage = nil
        } catch CalendarError.unauthorized {
            GoogleAuthService.shared.signOut()
            statusMessage = CalendarError.unauthorized.localizedDescription
        } catch {
            statusMessage = error.localizedDescription
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

    private func enqueueAnimation(title: String, timeRange: String?, dedupeKey: String?) {
        animationQueue.append(FlyoverPayload(title: title, timeRange: timeRange))
        processQueue()
    }

    private func processQueue() {
        guard !isPlayingAnimation, !animationQueue.isEmpty else { return }
        isPlayingAnimation = true
        let payload = animationQueue.removeFirst()
        OverlayWindowController.shared.playFlight(
            meetingTitle: payload.title,
            timeRange: payload.timeRange
        ) { [weak self] in
            Task { @MainActor in
                self?.isPlayingAnimation = false
                self?.processQueue()
            }
        }
    }
}
