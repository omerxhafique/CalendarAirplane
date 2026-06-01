import Foundation

@MainActor
final class TodayAgendaStore: ObservableObject {
    static let shared = TodayAgendaStore()

    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let calendarService = CalendarSyncService()

    private init() {}

    func clear() {
        events = []
        errorMessage = nil
    }

    func refresh() async {
        guard GoogleAuthService.shared.isSignedIn else {
            events = []
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await GoogleAuthService.shared.getValidAccessToken()
            let range = Self.todayRange()
            let fetched = try await calendarService.fetchEvents(
                from: range.start,
                to: range.end,
                accessToken: token,
                maxResults: 50
            )
            events = fetched.filter { $0.startDate < range.end }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func todayRange(calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return (start, end)
    }

    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func formatTimeRange(for event: CalendarEvent) -> String {
        if event.isAllDay {
            return "All day"
        }
        let start = formatTime(event.startDate)
        guard let endDate = event.endDate else { return start }
        return "\(start) – \(formatTime(endDate))"
    }
}
