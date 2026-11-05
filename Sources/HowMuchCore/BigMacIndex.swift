import Foundation

/// One row of the local Big Mac price table. Prices are unsmoothed local menu
/// prices from The Economist's Big Mac Index (January 2025 edition), one market
/// per currency the app supports. The index has no separate country row for the
/// euro, so the Euro area value is used for EUR.
///
/// Source: https://github.com/TheEconomist/big-mac-data (2025-01-01 raw index).
public struct BigMacPrice: Equatable, Identifiable, Sendable {
    public let currency: CurrencyUnit
    public let countryNameEn: String
    public let countryNameZh: String
    public let localPrice: Double

    public var id: CurrencyUnit { currency }

    public func countryName(in language: AppLanguage) -> String {
        language == .zhHans ? countryNameZh : countryNameEn
    }
}

/// The small price table behind the "how many Big Macs did I earn?" counter.
/// Amounts in this app are never currency-converted, so the matching local
/// price is the only sensible denominator for the selected display currency.
public enum BigMacIndex {
    public static let prices: [BigMacPrice] = [
        BigMacPrice(
            currency: .cny,
            countryNameEn: "China",
            countryNameZh: "中国",
            localPrice: 25.50
        ),
        BigMacPrice(
            currency: .usd,
            countryNameEn: "United States",
            countryNameZh: "美国",
            localPrice: 5.79
        ),
        BigMacPrice(
            currency: .eur,
            countryNameEn: "Euro area",
            countryNameZh: "欧元区",
            localPrice: 5.67
        ),
        BigMacPrice(
            currency: .gbp,
            countryNameEn: "United Kingdom",
            countryNameZh: "英国",
            localPrice: 4.59
        ),
        BigMacPrice(
            currency: .jpy,
            countryNameEn: "Japan",
            countryNameZh: "日本",
            localPrice: 480
        ),
        BigMacPrice(
            currency: .hkd,
            countryNameEn: "Hong Kong",
            countryNameZh: "中国香港",
            localPrice: 24
        ),
        BigMacPrice(
            currency: .krw,
            countryNameEn: "South Korea",
            countryNameZh: "韩国",
            localPrice: 5_500
        ),
        BigMacPrice(
            currency: .sgd,
            countryNameEn: "Singapore",
            countryNameZh: "新加坡",
            localPrice: 6.95
        )
    ]

    private static let priceByCurrency: [CurrencyUnit: BigMacPrice] = Dictionary(
        uniqueKeysWithValues: prices.map { ($0.currency, $0) }
    )

    public static func price(for currency: CurrencyUnit) -> BigMacPrice {
        // Every CurrencyUnit has a row; the fallback keeps the API total.
        priceByCurrency[currency] ?? prices[0]
    }

    /// Whole burgers affordable with `amount` of `currency`. Falls back to zero
    /// for invalid or negative earnings rather than trapping on huge values.
    public static func count(amount: Double, currency: CurrencyUnit) -> Int {
        let price = price(for: currency).localPrice
        guard amount.isFinite, amount > 0, price.isFinite, price > 0 else {
            return 0
        }

        let raw = (amount / price).rounded(.down)
        guard raw.isFinite, raw > 0 else { return 0 }
        return raw >= Double(Int.max) ? Int.max : Int(raw)
    }
}
