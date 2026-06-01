import Foundation

struct CalendarSyncService: Sendable {
    func fetchEvents(from start: Date, to end: Date, accessToken: String) async throws -> [CalendarEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: start)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "25"),
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
            guard let startDate = parseStart(item.start) else { return nil }
            return CalendarEvent(id: id, title: title, startDate: startDate)
        }
    }

    private func parseStart(_ start: EventDateTime?) -> Date? {
        if let dateTime = start?.dateTime {
            return ISO8601DateFormatter().date(from: dateTime)
        }
        if let date = start?.date {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone.current
            return f.date(from: date)
        }
        return nil
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
    let start: EventDateTime?
}

private struct EventDateTime: Decodable {
    let dateTime: String?
    let date: String?
}
