import Combine
import Foundation
import HowMuchCore

@MainActor
final class AppModel: ObservableObject {
    private enum StorageKey {
        static let settings = "jinzhang.paySettings.v1"
        static let session = "jinzhang.workSession.v1"
        static let hasLaunched = "jinzhang.hasLaunched.v1"
    }

    @Published var settings: PaySettings {
        didSet {
            guard !isHydrating else { return }
            persist(settings, key: StorageKey.settings)
        }
    }

    @Published var session: WorkSession {
        didSet {
            guard !isHydrating else { return }
            persist(session, key: StorageKey.session)
        }
    }

    @Published private(set) var now: Date

    private let defaults: UserDefaults
    private var ticker: Timer?
    private var isHydrating = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        var initialSettings = PaySettings.default
        initialSettings.overtimeHourlyRate = initialSettings.suggestedOvertimeHourlyRate
        if let stored: PaySettings = Self.load(PaySettings.self, key: StorageKey.settings, from: defaults) {
            initialSettings = stored
        }

        let initialSession: WorkSession =
            Self.load(WorkSession.self, key: StorageKey.session, from: defaults) ?? .idle

        self.settings = initialSettings
        self.session = initialSession
        self.now = Date()
        self.isHydrating = false

        startTicker()
    }

    deinit {
        ticker?.invalidate()
    }

    // MARK: - Derived state

    var snapshot: EarningsSnapshot {
        EarningsCalculator.snapshot(settings: settings, session: session, at: now)
    }

    var canClockIn: Bool {
        session.phase == .idle || session.phase == .clockedOut || session.phase == .finished
    }

    var canClockOut: Bool {
        session.phase == .working
    }

    var canStartOvertime: Bool {
        session.phase == .clockedOut
    }

    var canEndOvertime: Bool {
        session.phase == .overtime
    }

    var clockInStartsNewSession: Bool {
        session.phase != .idle
    }

    var phaseHint: String {
        switch session.phase {
        case .idle:
            return "点击「打卡上班」，开始记录今天的收入"
        case .working:
            return "正常计薪中，点击「打卡下班」结束本轮"
        case .clockedOut:
            return "已下班，可以开始加班，或重新打卡"
        case .overtime:
            return "加班计薪中，点击「结束加班」完成本次"
        case .finished:
            return "本次已完成，再次上班会开启新记录"
        }
    }

    // MARK: - Actions

    func clockIn() {
        session = SessionEngine.apply(.clockIn, to: session, at: Date())
        now = Date()
    }

    func clockOut() {
        session = SessionEngine.apply(.clockOut, to: session, at: Date())
        now = Date()
    }

    func startOvertime() {
        session = SessionEngine.apply(.startOvertime, to: session, at: Date())
        now = Date()
    }

    func endOvertime() {
        session = SessionEngine.apply(.endOvertime, to: session, at: Date())
        now = Date()
    }

    func resetSession() {
        session = .idle
        now = Date()
    }

    func useSuggestedOvertimeRate() {
        settings.overtimeHourlyRate = settings.suggestedOvertimeHourlyRate
    }

    func markLaunched() {
        defaults.set(true, forKey: StorageKey.hasLaunched)
    }

    var hasLaunchedBefore: Bool {
        defaults.bool(forKey: StorageKey.hasLaunched)
    }

    // MARK: - Ticker

    private func startTicker() {
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.now = Date()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    // MARK: - Persistence

    private func persist<T: Encodable>(_ value: T, key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(
        _ type: T.Type,
        key: String,
        from defaults: UserDefaults
    ) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}
