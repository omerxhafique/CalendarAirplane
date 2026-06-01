import Foundation

struct CalendarSyncService: Sendable {
    func fetchEvents(
        from start: Date,
        to end: Date,
        accessToken: String,
        maxResults: Int = 25
    ) async throws -> [CalendarEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: start)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: String(max(1, min(maxResults, 250)))),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CalendarError.invalidResponse
        }
        if http.statusCode == 401 {
            throw CalendarError.unauthorized
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw CalendarError.server(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(EventsListResponse.self, from: data)
        return (decoded.items ?? []).compactMap { item -> CalendarEvent? in
            guard let id = item.id else { return nil }
            let title = (item.summary?.isEmpty == false) ? item.summary! : "Untitled meeting"
            guard let start = parseEventDateTime(item.start) else { return nil }
            let end = parseEventDateTime(item.end)?.date
            let notes = plainNotes(from: item.description)
            return CalendarEvent(
                id: id,
                title: title,
                startDate: start.date,
                endDate: end,
                notes: notes,
                isAllDay: start.isAllDay
            )
        }
    }

    private func parseEventDateTime(_ value: EventDateTime?) -> (date: Date, isAllDay: Bool)? {
        if let dateTime = value?.dateTime {
            guard let date = ISO8601DateFormatter().date(from: dateTime) else { return nil }
            return (date, false)
        }
        if let date = value?.date {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone.current
            guard let parsed = f.date(from: date) else { return nil }
            return (parsed, true)
        }
        return nil
    }

    private func plainNotes(from description: String?) -> String? {
        guard var text = description?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        if text.contains("<") {
            text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
            text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            text = text
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&quot;", with: "\"")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

enum CalendarError: LocalizedError {
    case invalidResponse
    case unauthorized
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid calendar response."
        case .unauthorized: return "Google sign-in expired. Sign in again."
        case .server(let code): return "Calendar API error (\(code))."
        }
    }
}

private struct EventsListResponse: Decodable {
    let items: [EventItem]?
}

private struct EventItem: Decodable {
    let id: String?
    let summary: String?
    let description: String?
    let start: EventDateTime?
    let end: EventDateTime?
}

private struct EventDateTime: Decodable {
    let dateTime: String?
    let date: String?
}
