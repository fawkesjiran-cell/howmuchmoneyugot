import Foundation
import HowMuchCore

enum Fmt {
    private static func makeFormatter(
        locale: String,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int,
        grouping: Bool
    ) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: locale)
        formatter.usesGroupingSeparator = grouping
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter
    }

    private static let groupedZh = makeFormatter(
        locale: "zh_CN",
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
        grouping: true
    )
    private static let groupedEn = makeFormatter(
        locale: "en_US",
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
        grouping: true
    )
    private static let plainZh = makeFormatter(
        locale: "zh_CN",
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
        grouping: false
    )
    private static let plainEn = makeFormatter(
        locale: "en_US",
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
        grouping: false
    )
    private static let preciseZh = makeFormatter(
        locale: "zh_CN",
        minimumFractionDigits: 4,
        maximumFractionDigits: 4,
        grouping: true
    )
    private static let preciseEn = makeFormatter(
        locale: "en_US",
        minimumFractionDigits: 4,
        maximumFractionDigits: 4,
        grouping: true
    )
    private static let integerZh = makeFormatter(
        locale: "zh_CN",
        minimumFractionDigits: 0,
        maximumFractionDigits: 0,
        grouping: true
    )
    private static let integerEn = makeFormatter(
        locale: "en_US",
        minimumFractionDigits: 0,
        maximumFractionDigits: 0,
        grouping: true
    )

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func amount(
        _ value: Double,
        language: AppLanguage,
        grouped: Bool = true
    ) -> String {
        let safe = value.isFinite ? max(0, value) : 0
        let formatter: NumberFormatter
        switch (language, grouped) {
        case (.zhHans, true): formatter = groupedZh
        case (.zhHans, false): formatter = plainZh
        case (.english, true): formatter = groupedEn
        case (.english, false): formatter = plainEn
        }
        return formatter.string(from: NSNumber(value: safe)) ?? "0.00"
    }

    static func preciseAmount(_ value: Double, language: AppLanguage) -> String {
        let safe = value.isFinite ? max(0, value) : 0
        let formatter = language == .zhHans ? preciseZh : preciseEn
        return formatter.string(from: NSNumber(value: safe)) ?? "0.0000"
    }

    /// Compact, fixed-decimals rendering for the small per-second / per-minute
    /// rates. Keeps 4 decimals for seconds, 3 for minutes and 2 for hours so the
    /// three cards read as one consistent scale.
    static func rate(_ value: Double, decimals: Int) -> String {
        let safe = value.isFinite ? max(0, value) : 0
        return String(format: "%.*f", max(0, min(decimals, 6)), safe)
    }

    static func count(_ value: Double, language: AppLanguage) -> String {
        let safe = value.isFinite ? max(0, value) : 0
        let formatter = language == .zhHans ? integerZh : integerEn
        return formatter.string(from: NSNumber(value: safe)) ?? "0"
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        return clock.string(from: date)
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
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
