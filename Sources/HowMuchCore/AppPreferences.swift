import Foundation

/// Languages supported by the app. The raw values are suitable for persistence.
public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case zhHans = "zh-Hans"
    case english = "en"

    public var id: String { rawValue }

    public var nativeName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .english: return "English"
        }
    }

    public var localeIdentifier: String {
        switch self {
        case .zhHans: return "zh_CN"
        case .english: return "en_US"
        }
    }

    public static func systemDefault(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        guard let first = preferredLanguages.first else { return .zhHans }
        return first.lowercased().hasPrefix("zh") ? .zhHans : .english
    }
}

/// Currency units used only for display. Switching currency never converts the
/// numeric salary values.
public enum CurrencyUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case cny
    case usd
    case eur
    case gbp
    case jpy
    case hkd
    case krw
    case sgd

    public var id: String { rawValue }

    public var code: String {
        rawValue.uppercased()
    }

    public var symbol: String {
        switch self {
        case .cny: return "¥"
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "JP¥"
        case .hkd: return "HK$"
        case .krw: return "₩"
        case .sgd: return "S$"
        }
    }

    public func name(in language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            switch self {
            case .cny: return "人民币"
            case .usd: return "美元"
            case .eur: return "欧元"
            case .gbp: return "英镑"
            case .jpy: return "日元"
            case .hkd: return "港币"
            case .krw: return "韩元"
            case .sgd: return "新加坡元"
            }
        case .english:
            switch self {
            case .cny: return "Chinese Yuan"
            case .usd: return "US Dollar"
            case .eur: return "Euro"
            case .gbp: return "British Pound"
            case .jpy: return "Japanese Yen"
            case .hkd: return "Hong Kong Dollar"
            case .krw: return "Korean Won"
            case .sgd: return "Singapore Dollar"
            }
        }
    }

    public func menuLabel(in language: AppLanguage) -> String {
        "\(name(in: language)) · \(code)"
    }
}
