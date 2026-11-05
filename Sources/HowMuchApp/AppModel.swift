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
        static let theme = "jinzhang.theme.v1"
        static let ledger = "jinzhang.earningsLedger.v1"
        static let bigMacCounter = "jinzhang.bigMacCounter.v1"
        static let checkForUpdates = "jinzhang.checkForUpdates.v1"
        static let autoUpdate = "jinzhang.autoUpdate.v1"
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

    @Published var theme: ThemePreference {
        didSet {
            guard !isHydrating else { return }
            defaults.set(theme.rawValue, forKey: StorageKey.theme)
        }
    }

    @Published var ledger: EarningsLedger {
        didSet {
            guard !isHydrating else { return }
            persist(ledger, key: StorageKey.ledger)
        }
    }

    /// Optional Easter-egg counter. Off by default so the dashboard stays as
    /// quiet as before unless the user asks for burgers.
    @Published var bigMacCounterEnabled: Bool {
        didSet {
            guard !isHydrating else { return }
            defaults.set(bigMacCounterEnabled, forKey: StorageKey.bigMacCounter)
        }
    }

#if !HOWMUCH_OFFLINE
    /// Opt-in GitHub Releases update checking. Both switches are off by default
    /// so the app remains fully local unless the user asks for network access.
    @Published var checkForUpdatesEnabled: Bool {
        didSet {
            guard !isHydrating else { return }
            defaults.set(checkForUpdatesEnabled, forKey: StorageKey.checkForUpdates)
            if !checkForUpdatesEnabled, autoUpdateEnabled {
                autoUpdateEnabled = false
            }
            configureUpdater()
        }
    }

    @Published var autoUpdateEnabled: Bool {
        didSet {
            guard !isHydrating else { return }
            defaults.set(autoUpdateEnabled, forKey: StorageKey.autoUpdate)
            if autoUpdateEnabled, !checkForUpdatesEnabled {
                checkForUpdatesEnabled = true
            }
            configureUpdater()
        }
    }
#endif

    /// True while the status-bar panel is on screen. Dashboard animations check
    /// this so an off-screen view never plays a drop the user cannot see.
    @Published private(set) var isPanelPresented = false

    @Published private(set) var now: Date

    /// Shared across dashboard visits so a burger that has landed never gets
    /// repositioned by a later view rebuild.
    let bigMacPile = BigMacPileModel()

#if !HOWMUCH_OFFLINE
    let updater = UpdateController()
#endif

    private let defaults: UserDefaults
    private var ticker: Timer?
#if !HOWMUCH_OFFLINE
    private var updateTimer: Timer?
    private var updateKickoffTask: Task<Void, Never>?
#endif
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
        let initialTheme = defaults
            .string(forKey: StorageKey.theme)
            .flatMap(ThemePreference.init(rawValue:))
            ?? .system
        let initialLedger: EarningsLedger =
            Self.load(EarningsLedger.self, key: StorageKey.ledger, from: defaults) ?? .empty
        let initialBigMacCounter = defaults.bool(forKey: StorageKey.bigMacCounter)
#if !HOWMUCH_OFFLINE
        let storedAutoUpdate = defaults.bool(forKey: StorageKey.autoUpdate)
        let initialCheckForUpdates = defaults.bool(forKey: StorageKey.checkForUpdates)
            || storedAutoUpdate
#endif

        self.settings = initialSettings
        self.session = initialSession
        self.language = initialLanguage
        self.currency = initialCurrency
        self.theme = initialTheme
        self.ledger = initialLedger
        self.bigMacCounterEnabled = initialBigMacCounter
#if !HOWMUCH_OFFLINE
        self.checkForUpdatesEnabled = initialCheckForUpdates
        self.autoUpdateEnabled = storedAutoUpdate
#endif
        self.now = Date()
        self.isHydrating = false

        startTicker()
#if !HOWMUCH_OFFLINE
        configureUpdater()
#endif
    }

    deinit {
        ticker?.invalidate()
#if !HOWMUCH_OFFLINE
        updateTimer?.invalidate()
        updateKickoffTask?.cancel()
#endif
    }

    // MARK: - Derived state

    var snapshot: EarningsSnapshot {
        EarningsCalculator.snapshot(settings: settings, session: session, at: now)
    }

    var totalEarned: Double {
        ledger.total(current: snapshot.total)
    }

    var hasAnyEarnings: Bool {
        totalEarned > 0
    }

    // MARK: - Big Mac counter

    var bigMacPrice: BigMacPrice {
        BigMacIndex.price(for: currency)
    }

    var bigMacCount: Int {
        guard bigMacCounterEnabled else { return 0 }
        return BigMacIndex.count(amount: snapshot.total, currency: currency)
    }

    func setPanelPresented(_ presented: Bool) {
        guard isPanelPresented != presented else { return }
        isPanelPresented = presented
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

    /// Clears every accumulated amount: the persistent all-time ledger and the
    /// session in progress (which also stops any running timer). Preferences and
    /// pay settings are kept.
    func resetEverything() {
        ledger = .empty
        session = .idle
        now = Date()
    }

    func useSuggestedOvertimeRate() {
        settings.overtimeHourlyRate = settings.suggestedOvertimeHourlyRate
    }

    func updateMonthlySalary(_ value: Double) {
        settings.updateMonthlySalary(value)
    }

#if !HOWMUCH_OFFLINE
    // MARK: - Updates

#if DEBUG
    func previewAvailableUpdate(_ version: String) {
        checkForUpdatesEnabled = true
        updateKickoffTask?.cancel()
        updateKickoffTask = nil
        updateTimer?.invalidate()
        updateTimer = nil
        updater.setPreviewStatus(.available(version))
    }
#endif

    func checkForUpdatesManually() {
        updater.check(autoUpdate: autoUpdateEnabled)
    }

    func installAvailableUpdate() {
        updater.installAvailableUpdate()
    }

    private func configureUpdater() {
        updateKickoffTask?.cancel()
        updateKickoffTask = nil

        guard checkForUpdatesEnabled else {
            updateTimer?.invalidate()
            updateTimer = nil
            updater.disable()
            return
        }

        startUpdateTimer()

        updateKickoffTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled, let self, self.checkForUpdatesEnabled else { return }

            switch self.updater.status {
            case .checking, .downloading, .preparing, .installing:
                return
            case .available where self.autoUpdateEnabled:
                self.updater.installAvailableUpdate()
                return
            default:
                break
            }

            switch self.updater.status {
            case .upToDate, .available:
                if let lastChecked = self.updater.lastChecked,
                   Date().timeIntervalSince(lastChecked) < 600 {
                    return
                }
            default:
                break
            }
            self.updater.check(autoUpdate: self.autoUpdateEnabled)
        }
    }

    private func startUpdateTimer() {
        guard updateTimer == nil else { return }
        let timer = Timer(timeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.checkForUpdatesEnabled else { return }
                self.updater.check(autoUpdate: self.autoUpdateEnabled)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        updateTimer = timer
    }

#endif

    func cycleTheme() {
        theme = theme.next
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
