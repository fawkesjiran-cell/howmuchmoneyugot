import Darwin
import Foundation
import HowMuchCore

var failures = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: String = "", line: UInt = #line) {
    guard condition() else {
        failures += 1
        fputs("  ✗ line \(line): \(message)\n", stderr)
        return
    }
}

func expectClose(
    _ actual: Double,
    _ expected: Double,
    accuracy: Double = 0.000_001,
    _ message: String = "",
    line: UInt = #line
) {
    guard actual.isFinite, abs(actual - expected) <= accuracy else {
        failures += 1
        fputs("  ✗ line \(line): \(message) — got \(actual), expected \(expected)\n", stderr)
        return
    }
}

func section(_ title: String) {
    print("• \(title)")
}

let start = Date(timeIntervalSince1970: 1_700_000_000)
let settings = PaySettings(
    monthlySalary: 22_000,
    workDaysPerMonth: 22,
    hoursPerDay: 8,
    overtimeHourlyRate: 187.5
)

section("rate conversion")
expectClose(settings.dailyPay, 1_000, "daily pay")
expectClose(settings.normalHourlyRate, 125, "hourly rate")
expectClose(settings.normalPerMinuteRate, 125.0 / 60, "minute rate")
expectClose(settings.normalPerSecondRate, 125.0 / 3_600, "second rate")
expectClose(settings.overtimePerMinuteRate, 3.125, "overtime minute rate")
expectClose(settings.overtimePerSecondRate, 187.5 / 3_600, "overtime second rate")

section("ordinary earnings accumulate by the second")
do {
    let session = WorkSession(phase: .working, normalStartedAt: start)
    let snapshot = EarningsCalculator.snapshot(
        settings: settings,
        session: session,
        at: start.addingTimeInterval(3_600)
    )
    expectClose(snapshot.normalSeconds, 3_600, "normal seconds")
    expectClose(snapshot.normalEarned, 125, "normal earned")
    expectClose(snapshot.total, 125, "total")
    expectClose(snapshot.overtimeEarned, 0, "overtime earned")
    expect(snapshot.isEarning, "should be earning")
    expect(!snapshot.isOvertime, "should not be overtime")
}

section("overtime adds to finished ordinary pay")
do {
    let normalEnd = start.addingTimeInterval(8 * 3_600)
    let session = WorkSession(
        phase: .overtime,
        normalStartedAt: start,
        normalEndedAt: normalEnd,
        overtimeStartedAt: normalEnd
    )
    let snapshot = EarningsCalculator.snapshot(
        settings: settings,
        session: session,
        at: start.addingTimeInterval(9 * 3_600)
    )
    expectClose(snapshot.normalEarned, 1_000, "normal earned")
    expectClose(snapshot.overtimeEarned, 187.5, "overtime earned")
    expectClose(snapshot.total, 1_187.5, "total")
    expectClose(snapshot.overtimeSeconds, 3_600, "overtime seconds")
    expect(snapshot.isOvertime, "should be overtime")
}

section("finished session stops accumulating")
do {
    let session = WorkSession(
        phase: .finished,
        normalStartedAt: start,
        normalEndedAt: start.addingTimeInterval(3_600),
        overtimeStartedAt: start.addingTimeInterval(3_600),
        overtimeEndedAt: start.addingTimeInterval(5_400)
    )
    let atFinish = EarningsCalculator.snapshot(
        settings: settings,
        session: session,
        at: start.addingTimeInterval(5_400)
    )
    let muchLater = EarningsCalculator.snapshot(
        settings: settings,
        session: session,
        at: start.addingTimeInterval(50_000)
    )
    expectClose(atFinish.total, muchLater.total, accuracy: 0, "total should be frozen")
    expectClose(atFinish.overtimeSeconds, 1_800, "overtime seconds")
    expect(!atFinish.isEarning, "should not be earning")
}

section("timestamps survive encoding round trip")
do {
    let session = WorkSession(
        phase: .overtime,
        normalStartedAt: start,
        normalEndedAt: start.addingTimeInterval(3_600),
        overtimeStartedAt: start.addingTimeInterval(4_000)
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    if let data = try? encoder.encode(session),
       let decoded = try? decoder.decode(WorkSession.self, from: data) {
        expect(decoded == session, "decoded session should equal original")
    } else {
        expect(false, "encoding round trip failed")
    }
}

section("invalid settings produce zero rates")
do {
    let invalid = PaySettings(
        monthlySalary: 0,
        workDaysPerMonth: 0,
        hoursPerDay: 0,
        overtimeHourlyRate: 0
    )
    expect(!invalid.isValid, "settings should be invalid")
    expectClose(invalid.normalPerSecondRate, 0)
    expectClose(invalid.dailyPay, 0)
}

section("clock changes backwards never create negative earnings")
do {
    let session = WorkSession(phase: .working, normalStartedAt: start)
    let snapshot = EarningsCalculator.snapshot(
        settings: settings,
        session: session,
        at: start.addingTimeInterval(-60)
    )
    expectClose(snapshot.total, 0)
}

section("full workday state flow")
do {
    var session = SessionEngine.apply(.clockIn, to: .idle, at: start)
    expect(session.phase == .working, "phase should be working")
    expect(session.normalStartedAt == start, "normal start should be saved")

    let clockOut = start.addingTimeInterval(8 * 3_600)
    session = SessionEngine.apply(.clockOut, to: session, at: clockOut)
    expect(session.phase == .clockedOut, "phase should be clockedOut")
    expect(session.normalEndedAt == clockOut, "normal end should be saved")

    let overtimeStart = clockOut.addingTimeInterval(3_600)
    session = SessionEngine.apply(.startOvertime, to: session, at: overtimeStart)
    expect(session.phase == .overtime, "phase should be overtime")
    expect(session.overtimeStartedAt == overtimeStart, "overtime start should be saved")

    let overtimeEnd = overtimeStart.addingTimeInterval(2 * 3_600)
    session = SessionEngine.apply(.endOvertime, to: session, at: overtimeEnd)
    expect(session.phase == .finished, "phase should be finished")
    expect(session.overtimeEndedAt == overtimeEnd, "overtime end should be saved")
}

section("starting overtime while working closes ordinary interval")
do {
    let session = SessionEngine.apply(.clockIn, to: .idle, at: start)
    let overtimeStart = start.addingTimeInterval(4 * 3_600)
    let next = SessionEngine.apply(.startOvertime, to: session, at: overtimeStart)
    expect(next.phase == .overtime, "phase should be overtime")
    expect(next.normalEndedAt == overtimeStart, "normal interval should close")
    expect(next.overtimeStartedAt == overtimeStart, "overtime should start")
}

section("invalid transitions are ignored")
do {
    expect(SessionEngine.apply(.clockOut, to: .idle, at: start) == .idle)
    expect(SessionEngine.apply(.endOvertime, to: .idle, at: start) == .idle)

    let working = WorkSession(phase: .working, normalStartedAt: start)
    expect(SessionEngine.apply(.clockIn, to: working, at: start) == working)
    expect(SessionEngine.apply(.endOvertime, to: working, at: start) == working)
}

section("clock in after finish starts a fresh session")
do {
    let finished = WorkSession(
        phase: .finished,
        normalStartedAt: start,
        normalEndedAt: start.addingTimeInterval(3_600),
        overtimeStartedAt: start.addingTimeInterval(4_000),
        overtimeEndedAt: start.addingTimeInterval(5_000)
    )
    let next = SessionEngine.apply(
        .clockIn,
        to: finished,
        at: start.addingTimeInterval(10_000)
    )
    expect(next.phase == .working, "phase should be working")
    expect(next.normalStartedAt == start.addingTimeInterval(10_000), "new start time")
    expect(next.normalEndedAt == nil, "normal end should be nil")
    expect(next.overtimeStartedAt == nil, "overtime start should be nil")
    expect(next.overtimeEndedAt == nil, "overtime end should be nil")
}

section("reset clears everything")
do {
    let session = WorkSession(
        phase: .overtime,
        normalStartedAt: start,
        normalEndedAt: start.addingTimeInterval(3_600),
        overtimeStartedAt: start.addingTimeInterval(4_000)
    )
    expect(SessionEngine.apply(.reset, to: session, at: start) == .idle)
}


section("language and currency preferences")
do {
    expect(AppLanguage.zhHans.nativeName == "简体中文")
    expect(AppLanguage.english.nativeName == "English")
    expect(AppLanguage.zhHans.localeIdentifier == "zh_CN")
    expect(AppLanguage.english.localeIdentifier == "en_US")
    expect(AppLanguage.systemDefault(preferredLanguages: ["zh-Hans-CN"]) == .zhHans)
    expect(AppLanguage.systemDefault(preferredLanguages: ["en-US"]) == .english)

    expect(CurrencyUnit.cny.code == "CNY")
    expect(CurrencyUnit.usd.symbol == "$")
    expect(CurrencyUnit.jpy.symbol == "JP¥")
    expect(CurrencyUnit.hkd.symbol == "HK$")
    expect(CurrencyUnit.eur.name(in: .zhHans) == "欧元")
    expect(CurrencyUnit.eur.name(in: .english) == "Euro")
    expect(CurrencyUnit.cny.menuLabel(in: .english) == "Chinese Yuan · CNY")

    let encoded = try? JSONEncoder().encode(CurrencyUnit.sgd)
    let decoded = encoded.flatMap { try? JSONDecoder().decode(CurrencyUnit.self, from: $0) }
    expect(decoded == .sgd, "currency should survive Codable round trip")
}

if failures == 0 {
    print("\n✓ All core checks passed")
    exit(0)
} else {
    print("\n✗ \(failures) check(s) failed")
    exit(1)
}
