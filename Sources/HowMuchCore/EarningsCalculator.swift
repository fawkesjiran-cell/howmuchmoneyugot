import Foundation

/// An immutable view of the session's earnings at one instant.
public struct EarningsSnapshot: Equatable, Sendable {
    public let phase: WorkPhase
    public let normalSeconds: TimeInterval
    public let overtimeSeconds: TimeInterval
    public let normalEarned: Double
    public let overtimeEarned: Double
    public let normalPerSecondRate: Double
    public let normalPerMinuteRate: Double
    public let normalHourlyRate: Double
    public let overtimePerSecondRate: Double
    public let overtimePerMinuteRate: Double
    public let overtimeHourlyRate: Double

    public var total: Double {
        normalEarned + overtimeEarned
    }

    public var totalSeconds: TimeInterval {
        normalSeconds + overtimeSeconds
    }

    public var isEarning: Bool {
        phase.isEarning
    }

    public var isOvertime: Bool {
        phase == .overtime
    }

    /// The rate that is currently being added to the total.
    public var activePerSecondRate: Double {
        isOvertime ? overtimePerSecondRate : normalPerSecondRate
    }

    public var activePerMinuteRate: Double {
        isOvertime ? overtimePerMinuteRate : normalPerMinuteRate
    }

    public var activeHourlyRate: Double {
        isOvertime ? overtimeHourlyRate : normalHourlyRate
    }
}

public enum EarningsCalculator {
    public static func snapshot(
        settings: PaySettings,
        session: WorkSession,
        at now: Date
    ) -> EarningsSnapshot {
        let normalEnd: Date?
        switch session.phase {
        case .working:
            normalEnd = now
        case .clockedOut, .overtime, .finished:
            normalEnd = session.normalEndedAt
        case .idle:
            normalEnd = nil
        }

        let normalSeconds: TimeInterval
        if let start = session.normalStartedAt, let end = normalEnd {
            normalSeconds = max(0, end.timeIntervalSince(start))
        } else {
            normalSeconds = 0
        }

        let overtimeEnd: Date?
        switch session.phase {
        case .overtime:
            overtimeEnd = now
        case .finished:
            overtimeEnd = session.overtimeEndedAt
        case .idle, .working, .clockedOut:
            overtimeEnd = nil
        }

        let overtimeSeconds: TimeInterval
        if let start = session.overtimeStartedAt, let end = overtimeEnd {
            overtimeSeconds = max(0, end.timeIntervalSince(start))
        } else {
            overtimeSeconds = 0
        }

        return EarningsSnapshot(
            phase: session.phase,
            normalSeconds: normalSeconds,
            overtimeSeconds: overtimeSeconds,
            normalEarned: normalSeconds * settings.normalPerSecondRate,
            overtimeEarned: overtimeSeconds * settings.overtimePerSecondRate,
            normalPerSecondRate: settings.normalPerSecondRate,
            normalPerMinuteRate: settings.normalPerMinuteRate,
            normalHourlyRate: settings.normalHourlyRate,
            overtimePerSecondRate: settings.overtimePerSecondRate,
            overtimePerMinuteRate: settings.overtimePerMinuteRate,
            overtimeHourlyRate: settings.safeOvertimeHourlyRate
        )
    }
}
