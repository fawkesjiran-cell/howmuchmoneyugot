import Combine
import Foundation
import HowMuchCore

@MainActor
final class AppModel: ObservableObject {
    private enum StorageKey {
        static let settings = "jinzhang.paySettings.v1"
        static let session = "jinzhang.workSession.v1"
        static let language = "jinzhang.language.v1"
        static let currency = "jinzhang.currency.v1"
        static let ledger = "jinzhang.earningsLedger.v1"
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

    @Published var language: AppLanguage {
        didSet {
            guard !isHydrating else { return }
            defaults.set(language.rawValue, forKey: StorageKey.language)
        }
    }

    @Published var currency: CurrencyUnit {
        didSet {
            guard !isHydrating else { return }
            defaults.set(currency.rawValue, forKey: StorageKey.currency)
        }
    }

    @Published var ledger: EarningsLedger {
        didSet {
            guard !isHydrating else { return }
            persist(ledger, key: StorageKey.ledger)
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

        let initialLanguage = defaults
            .string(forKey: StorageKey.language)
            .flatMap(AppLanguage.init(rawValue:))
            ?? AppLanguage.systemDefault()
        let initialCurrency = defaults
            .string(forKey: StorageKey.currency)
            .flatMap(CurrencyUnit.init(rawValue:))
            ?? .cny
        let initialLedger: EarningsLedger =
            Self.load(EarningsLedger.self, key: StorageKey.ledger, from: defaults) ?? .empty

        self.settings = initialSettings
        self.session = initialSession
        self.language = initialLanguage
        self.currency = initialCurrency
        self.ledger = initialLedger
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

    var totalEarned: Double {
        ledger.total(current: snapshot.total)
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

    // MARK: - Localization & display

    func t(_ key: LKey, _ arguments: CVarArg...) -> String {
        L10n.text(key, language: language, arguments: arguments)
    }

    func amount(
        _ value: Double,
        precise: Bool = false,
        grouped: Bool = true
    ) -> String {
        precise
            ? Fmt.preciseAmount(value, language: language)
            : Fmt.amount(value, language: language, grouped: grouped)
    }

    func money(_ value: Double, precise: Bool = false) -> String {
        currency.symbol + amount(value, precise: precise)
    }

    func count(_ value: Double) -> String {
        Fmt.count(value, language: language)
    }

    func phaseTitle(_ phase: WorkPhase) -> String {
        switch phase {
        case .idle: return t(.phaseTitleIdle)
        case .working: return t(.phaseTitleWorking)
        case .clockedOut: return t(.phaseTitleClockedOut)
        case .overtime: return t(.phaseTitleOvertime)
        case .finished: return t(.phaseTitleFinished)
        }
    }


    // MARK: - Actions

    func clockIn() {
        now = Date()
        if session.phase == .clockedOut || session.phase == .finished {
            ledger.archive(snapshot.total)
        }
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
