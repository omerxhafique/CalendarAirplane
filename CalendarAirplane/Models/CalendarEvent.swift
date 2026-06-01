import Foundation

struct CalendarEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let notes: String?
    let isAllDay: Bool

    var dedupeKey: String {
        "\(id)|\(Int(startDate.timeIntervalSince1970))"
    }
}
