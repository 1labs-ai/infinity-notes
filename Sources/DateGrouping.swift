import Foundation

enum DateSection: Hashable {
    case today, yesterday, previous7Days, previous30Days
    case month(Int)
    case year(Int)

    func title(calendar: Calendar = .current) -> String {
        switch self {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .previous7Days: "Previous 7 Days"
        case .previous30Days: "Previous 30 Days"
        case .month(let month): calendar.standaloneMonthSymbols[month - 1]
        case .year(let year): String(year)
        }
    }

    static func section(for date: Date, now: Date, calendar: Calendar = .current) -> DateSection {
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch days {
        case ...0: return .today
        case 1: return .yesterday
        case 2...7: return .previous7Days
        case 8...30: return .previous30Days
        default:
            let year = calendar.component(.year, from: date)
            if year == calendar.component(.year, from: now) {
                return .month(calendar.component(.month, from: date))
            }
            return .year(year)
        }
    }

    /// Groups items already sorted newest-first, keeping that order within and across sections.
    static func group<T>(_ items: [T], date: (T) -> Date, now: Date, calendar: Calendar = .current) -> [(DateSection, [T])] {
        var result: [(DateSection, [T])] = []
        for item in items {
            let section = section(for: date(item), now: now, calendar: calendar)
            if let last = result.indices.last, result[last].0 == section {
                result[last].1.append(item)
            } else {
                result.append((section, [item]))
            }
        }
        return result
    }

    /// Row timestamp: time today, "Yesterday", weekday within a week, otherwise a short date.
    static func rowLabel(for date: Date, now: Date, calendar: Calendar = .current) -> String {
        switch section(for: date, now: now, calendar: calendar) {
        case .today: return date.formatted(date: .omitted, time: .shortened)
        case .yesterday: return "Yesterday"
        case .previous7Days: return date.formatted(.dateTime.weekday(.wide))
        default: return date.formatted(date: .numeric, time: .omitted)
        }
    }
}
