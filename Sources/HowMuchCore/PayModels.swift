import Foundation

/// The lifecycle of a single clock-in session.
public enum WorkPhase: String, Codable, CaseIterable, Sendable {
    case idle
    case working
    case clockedOut
    case overtime
    case finished

    public var isEarning: Bool {
        self == .working || self == .overtime
    }

    public var title: String {
        switch self {
        case .idle: return "待打卡"
        case .working: return "正常计薪中"
        case .clockedOut: return "已打卡下班"
        case .overtime: return "加班计薪中"
        case .finished: return "本次已完成"
        }
    }
}

/// Pay inputs. Rates are derived, never stored, so changing the work schedule
/// immediately updates every calculation.
public struct PaySettings: Codable, Equatable, Sendable {
    public var monthlySalary: Double
    public var workDaysPerMonth: Double
    public var hoursPerDay: Double
    public var overtimeHourlyRate: Double

    public init(
        monthlySalary: Double = 12_000,
        workDaysPerMonth: Double = 22,
        hoursPerDay: Double = 8,
        overtimeHourlyRate: Double = 102.27
    ) {
        self.monthlySalary = monthlySalary
        self.workDaysPerMonth = workDaysPerMonth
        self.hoursPerDay = hoursPerDay
        self.overtimeHourlyRate = overtimeHourlyRate
    }

    public static let `default` = PaySettings()

    private var safeMonthlySalary: Double {
        monthlySalary.isFinite ? max(0, monthlySalary) : 0
    }

    private var safeWorkDays: Double {
        workDaysPerMonth.isFinite ? max(0, workDaysPerMonth) : 0
    }

    private var safeHoursPerDay: Double {
        hoursPerDay.isFinite ? max(0, hoursPerDay) : 0
    }

    public var isValid: Bool {
        safeMonthlySalary > 0
            && safeWorkDays > 0
            && safeHoursPerDay > 0
    }

    /// Salary for one ordinary working day.
    public var dailyPay: Double {
        guard safeWorkDays > 0 else { return 0 }
        return safeMonthlySalary / safeWorkDays
    }

    /// Ordinary hourly pay derived from monthly salary, work days and daily hours.
    public var normalHourlyRate: Double {
        let monthlyHours = safeWorkDays * safeHoursPerDay
        guard monthlyHours > 0 else { return 0 }
        return safeMonthlySalary / monthlyHours
    }

    public var normalPerMinuteRate: Double {
        normalHourlyRate / 60
    }

    public var normalPerSecondRate: Double {
        normalHourlyRate / 3_600
    }

    public var safeOvertimeHourlyRate: Double {
        overtimeHourlyRate.isFinite ? max(0, overtimeHourlyRate) : 0
    }

    public var overtimePerMinuteRate: Double {
        safeOvertimeHourlyRate / 60
    }

    public var overtimePerSecondRate: Double {
        safeOvertimeHourlyRate / 3_600
    }

    /// The overtime rate expressed as a multiple of the ordinary hourly rate.
    public var overtimeMultiplier: Double {
        guard normalHourlyRate > 0 else { return 0 }
        return safeOvertimeHourlyRate / normalHourlyRate
    }

    /// A convenient 1.5x overtime rate, rounded to fen.
    public var suggestedOvertimeHourlyRate: Double {
        (normalHourlyRate * 1.5 * 100).rounded() / 100
    }

    /// Clamps obviously invalid input to a safe value before persisting.
    public mutating func sanitize() {
        if !monthlySalary.isFinite { monthlySalary = 0 }
        if !workDaysPerMonth.isFinite { workDaysPerMonth = 0 }
        if !hoursPerDay.isFinite { hoursPerDay = 0 }
        if !overtimeHourlyRate.isFinite { overtimeHourlyRate = 0 }
        monthlySalary = max(0, monthlySalary)
        workDaysPerMonth = max(0, workDaysPerMonth)
        hoursPerDay = max(0, hoursPerDay)
        overtimeHourlyRate = max(0, overtimeHourlyRate)
    }
}

/// Persistent timestamps for one session. All durations are derived from them,
/// which keeps the total accurate through app restarts and Mac sleep.
public struct WorkSession: Codable, Equatable, Sendable {
    public var phase: WorkPhase
    public var normalStartedAt: Date?
    public var normalEndedAt: Date?
    public var overtimeStartedAt: Date?
    public var overtimeEndedAt: Date?

    public init(
        phase: WorkPhase = .idle,
        normalStartedAt: Date? = nil,
        normalEndedAt: Date? = nil,
        overtimeStartedAt: Date? = nil,
        overtimeEndedAt: Date? = nil
    ) {
        self.phase = phase
        self.normalStartedAt = normalStartedAt
        self.normalEndedAt = normalEndedAt
        self.overtimeStartedAt = overtimeStartedAt
        self.overtimeEndedAt = overtimeEndedAt
    }

    public static let idle = WorkSession()

    public var hasRecordedTime: Bool {
        normalStartedAt != nil || overtimeStartedAt != nil
    }

    /// The first timestamp that belongs to this session.
    public var startedAt: Date? {
        [normalStartedAt, overtimeStartedAt].compactMap { $0 }.min()
    }

    public var lastActivityAt: Date? {
        [normalEndedAt, overtimeEndedAt, normalStartedAt, overtimeStartedAt]
            .compactMap { $0 }
            .max()
    }
}

public enum SessionAction: Sendable {
    case clockIn
    case clockOut
    case startOvertime
    case endOvertime
    case reset
}

public enum SessionEngine {
    /// Applies one user action. Invalid transitions leave the session untouched.
    public static func apply(
        _ action: SessionAction,
        to session: WorkSession,
        at date: Date
    ) -> WorkSession {
        switch action {
        case .clockIn:
            guard session.phase == .idle
                || session.phase == .clockedOut
                || session.phase == .finished
            else { return session }
            return WorkSession(phase: .working, normalStartedAt: date)

        case .clockOut:
            guard session.phase == .working else { return session }
            var next = session
            next.normalEndedAt = date
            if next.normalStartedAt == nil {
                next.normalStartedAt = date
            }
            next.phase = .clockedOut
            return next

        case .startOvertime:
            guard session.phase == .working || session.phase == .clockedOut else {
                return session
            }
            var next = session
            if next.phase == .working {
                next.normalEndedAt = date
            }
            next.overtimeStartedAt = date
            next.overtimeEndedAt = nil
            next.phase = .overtime
            return next

        case .endOvertime:
            guard session.phase == .overtime else { return session }
            var next = session
            next.overtimeEndedAt = date
            if next.overtimeStartedAt == nil {
                next.overtimeStartedAt = date
            }
            next.phase = .finished
            return next

        case .reset:
            return .idle
        }
    }
}
