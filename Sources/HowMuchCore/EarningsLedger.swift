import Foundation

/// Persistent all-time earnings accumulated from completed sessions.
public struct EarningsLedger: Codable, Equatable, Sendable {
    public private(set) var completedEarnings: Double
    public private(set) var completedSessions: Int

    public init(completedEarnings: Double = 0, completedSessions: Int = 0) {
        self.completedEarnings = completedEarnings.isFinite ? max(0, completedEarnings) : 0
        self.completedSessions = max(0, completedSessions)
    }

    public static let empty = EarningsLedger()

    /// Adds a completed session to the ledger. Non-finite or negative values are ignored.
    public mutating func archive(_ amount: Double) {
        guard amount.isFinite, amount > 0 else { return }
        completedEarnings += amount
        completedSessions += 1
    }

    /// The all-time total, including the session that is currently on screen.
    public func total(current: Double) -> Double {
        let safeCurrent = current.isFinite ? max(0, current) : 0
        return completedEarnings + safeCurrent
    }
}
