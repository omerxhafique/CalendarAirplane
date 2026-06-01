import Foundation

struct CalendarEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let startDate: Date

    var dedupeKey: String {
        "\(id)|\(Int(startDate.timeIntervalSince1970))"
    }
}
