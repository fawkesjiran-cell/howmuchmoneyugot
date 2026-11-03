import Foundation

enum Fmt {
    private static let grouped: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    private static let plain: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    private static let precise: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 4
        return formatter
    }()

    private static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    static func money(_ value: Double, grouped useGrouping: Bool = true) -> String {
        let safe = value.isFinite ? max(0, value) : 0
        return (useGrouping ? grouped : plain).string(from: NSNumber(value: safe)) ?? "0.00"
    }

    static func moneyPrecise(_ value: Double) -> String {
        let safe = value.isFinite ? max(0, value) : 0
        return precise.string(from: NSNumber(value: safe)) ?? "0.0000"
    }

    static func count(_ value: Double) -> String {
        let safe = value.isFinite ? max(0, value) : 0
        return integer.string(from: NSNumber(value: safe)) ?? "0"
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        return clock.string(from: date)
    }

    static func dayString(_ date: Date) -> String {
        day.string(from: date)
    }

    static func duration(_ interval: TimeInterval, paddedHours: Bool = true) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if paddedHours {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        if hours > 0 {
            return String(format: "%d小时%02d分", hours, minutes)
        }
        if minutes > 0 {
            return String(format: "%d分%02d秒", minutes, seconds)
        }
        return String(format: "%d秒", seconds)
    }

    static func compactDuration(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分"
        }
        if minutes > 0 {
            return "\(minutes)分"
        }
        return "\(total % 60)秒"
    }
}
