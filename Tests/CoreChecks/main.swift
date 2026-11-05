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

section("monthly salary seeds overtime but allows a custom override")
do {
    var updated = settings
    updated.updateMonthlySalary(30_000)
    expectClose(updated.monthlySalary, 30_000, "new monthly salary")
    expectClose(
        updated.overtimeHourlyRate,
        updated.suggestedOvertimeHourlyRate,
        "overtime should auto-fill at 1.5x"
    )
    expectClose(updated.overtimeHourlyRate, 255.68, "1.5x of 30k monthly")

    updated.overtimeHourlyRate = 300
    expectClose(updated.overtimeHourlyRate, 300, "custom overtime override")

    updated.updateMonthlySalary(40_000)
    expectClose(
        updated.overtimeHourlyRate,
        updated.suggestedOvertimeHourlyRate,
        "the next salary edit re-seeds 1.5x"
    )
}

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
    expect(AppMetadata.displayName == "How much money u got?")

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


section("Big Mac price table")
do {
    expect(
        BigMacIndex.prices.count == CurrencyUnit.allCases.count,
        "every supported currency needs one local Big Mac price"
    )
    for currency in CurrencyUnit.allCases {
        expect(
            BigMacIndex.price(for: currency).currency == currency,
            "price lookup should return the matching row"
        )
    }

    expectClose(BigMacIndex.price(for: .cny).localPrice, 25.50)
    expectClose(BigMacIndex.price(for: .usd).localPrice, 5.79)
    expectClose(BigMacIndex.price(for: .eur).localPrice, 5.67)
    expectClose(BigMacIndex.price(for: .gbp).localPrice, 4.59)
    expectClose(BigMacIndex.price(for: .jpy).localPrice, 480)
    expectClose(BigMacIndex.price(for: .hkd).localPrice, 24)
    expectClose(BigMacIndex.price(for: .krw).localPrice, 5_500)
    expectClose(BigMacIndex.price(for: .sgd).localPrice, 6.95)

    expect(BigMacIndex.price(for: .cny).countryName(in: .zhHans) == "中国")
    expect(BigMacIndex.price(for: .cny).countryName(in: .english) == "China")
    expect(BigMacIndex.price(for: .usd).countryName(in: .zhHans) == "美国")
}

section("Big Mac count")
do {
    expect(BigMacIndex.count(amount: 0, currency: .usd) == 0)
    expect(BigMacIndex.count(amount: -5, currency: .usd) == 0)
    expect(BigMacIndex.count(amount: 5.78, currency: .usd) == 0)
    expect(BigMacIndex.count(amount: 5.79, currency: .usd) == 1)
    expect(BigMacIndex.count(amount: 58, currency: .usd) == 10)
    expect(BigMacIndex.count(amount: 25.49, currency: .cny) == 0)
    expect(BigMacIndex.count(amount: 25.50, currency: .cny) == 1)
    expect(BigMacIndex.count(amount: 25.50 * 4, currency: .cny) == 4)
    expect(BigMacIndex.count(amount: 1_000_000, currency: .jpy) == 2_083)
    expect(BigMacIndex.count(amount: .nan, currency: .usd) == 0)
    expect(BigMacIndex.count(amount: .infinity, currency: .usd) == 0)
    expect(
        BigMacIndex.count(
            amount: .greatestFiniteMagnitude,
            currency: .usd
        ) == Int.max
    )
}


section("persistent earnings ledger")
do {
    var ledger = EarningsLedger.empty
    expectClose(ledger.total(current: 12.5), 12.5)
    ledger.archive(100)
    expectClose(ledger.completedEarnings, 100)
    expect(ledger.completedSessions == 1)
    expectClose(ledger.total(current: 12.5), 112.5)
    ledger.archive(50.25)
    expectClose(ledger.completedEarnings, 150.25)
    expect(ledger.completedSessions == 2)
    ledger.archive(-10)
    ledger.archive(Double.infinity)
    expectClose(ledger.completedEarnings, 150.25)
    expect(ledger.completedSessions == 2)
    expectClose(ledger.total(current: -5), 150.25)

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    if let data = try? encoder.encode(ledger),
       let decoded = try? decoder.decode(EarningsLedger.self, from: data) {
        expect(decoded == ledger, "ledger should survive Codable round trip")
    } else {
        expect(false, "ledger encoding round trip failed")
    }
}

section("update versions and GitHub release assets")
do {
    guard let v154 = AppVersion("1.5.4"),
          let v159 = AppVersion("v1.5.9"),
          let v1510 = AppVersion("v1.5.10") else {
        expect(false, "valid versions should parse")
        exit(1)
    }
    expect(v154 == AppVersion("v1.5.4"), "v prefix and plain version should match")
    expect(v1510 > v159, "1.5.10 should be newer than 1.5.9")
    expect(v159 > v154, "1.5.9 should be newer than 1.5.4")
    expect(AppVersion("1.5")?.description == "1.5.0", "missing patch should default to zero")
    expect(AppVersion("v1.5.4-beta.1") == v154, "prerelease suffix should not change numeric ordering")
    expect(AppVersion("not-a-version") == nil, "invalid version should be rejected")

    let names = [
        "How-Much-Money-U-Got-1.5.4-macOS-Electron-universal.zip",
        "How-Much-Money-U-Got-1.5.4-macOS-Swift.zip",
        "How-Much-Money-U-Got-1.5.4-Windows-Electron-x64.zip",
        "SHA256SUMS.txt"
    ]
    let swiftAsset = "How-Much-Money-U-Got-1.5.4-macOS-Swift.zip"
    expect(UpdateCatalog.swiftMacOSAssetName(from: names) == swiftAsset,
           "Swift macOS zip should be selected")
    expect(UpdateCatalog.swiftMacOSAssetName(from: ["README.md"]) == nil,
           "missing Swift asset should be reported")

    let hash = "b68150fadf6c9b38e7adaf64e8b6668495e3b20d86761002001a993d24bcc1a6"
    let checksums = """
    f9a6a755cb35ebc082fc1d7e0a75e49de0a787e49d4c7890805c2fbd93805575  How-Much-Money-U-Got-1.5.4-macOS-Electron-universal.zip
    \(hash)  \(swiftAsset)
    """
    expect(UpdateCatalog.checksum(forAssetNamed: swiftAsset, in: checksums) == hash,
           "checksum for the Swift zip should be found")
    expect(UpdateCatalog.checksum(forAssetNamed: "missing.zip", in: checksums) == nil,
           "missing checksum should be reported")
    expect(UpdateCatalog.isSHA256(hash), "64 hex characters should be a valid checksum")
    expect(!UpdateCatalog.isSHA256("abc"), "short checksum should be rejected")
}

if failures == 0 {
    print("\n✓ All core checks passed")
    exit(0)
} else {
    print("\n✗ \(failures) check(s) failed")
    exit(1)
}
