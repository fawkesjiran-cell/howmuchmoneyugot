(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.Core = factory();
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const CURRENCIES = {
    cny: { code: 'CNY', symbol: '¥', zh: '人民币', en: 'Chinese Yuan' },
    usd: { code: 'USD', symbol: '$', zh: '美元', en: 'US Dollar' },
    eur: { code: 'EUR', symbol: '€', zh: '欧元', en: 'Euro' },
    gbp: { code: 'GBP', symbol: '£', zh: '英镑', en: 'British Pound' },
    jpy: { code: 'JPY', symbol: 'JP¥', zh: '日元', en: 'Japanese Yen' },
    hkd: { code: 'HKD', symbol: 'HK$', zh: '港币', en: 'Hong Kong Dollar' },
    krw: { code: 'KRW', symbol: '₩', zh: '韩元', en: 'Korean Won' },
    sgd: { code: 'SGD', symbol: 'S$', zh: '新加坡元', en: 'Singapore Dollar' }
  };

  const LANGUAGES = {
    'zh-Hans': { nativeName: '简体中文', locale: 'zh-CN' },
    en: { nativeName: 'English', locale: 'en-US' }
  };

  // Local Big Mac menu prices from The Economist's January 2025 Big Mac Index
  // (https://github.com/TheEconomist/big-mac-data). One market per display
  // currency; the index reports the euro area rather than a single country.
  const BIG_MAC_PRICES = Object.freeze({
    cny: { code: 'CNY', country: 'China', countryZh: '中国', price: 25.50 },
    usd: { code: 'USD', country: 'United States', countryZh: '美国', price: 5.79 },
    eur: { code: 'EUR', country: 'Euro area', countryZh: '欧元区', price: 5.67 },
    gbp: { code: 'GBP', country: 'United Kingdom', countryZh: '英国', price: 4.59 },
    jpy: { code: 'JPY', country: 'Japan', countryZh: '日本', price: 480 },
    hkd: { code: 'HKD', country: 'Hong Kong', countryZh: '中国香港', price: 24 },
    krw: { code: 'KRW', country: 'South Korea', countryZh: '韩国', price: 5500 },
    sgd: { code: 'SGD', country: 'Singapore', countryZh: '新加坡', price: 6.95 }
  });

  const DEFAULT_SETTINGS = Object.freeze({
    monthlySalary: 12000,
    workDaysPerMonth: 22,
    hoursPerDay: 8,
    overtimeHourlyRate: 102.27
  });

  const SESSION_KEYS = [
    'normalStartedAt',
    'normalEndedAt',
    'overtimeStartedAt',
    'overtimeEndedAt'
  ];

  function finite(value, fallback = 0) {
    return Number.isFinite(Number(value)) ? Number(value) : fallback;
  }

  function clampNonNegative(value) {
    return Math.max(0, finite(value));
  }

  function sanitizeSettings(raw = {}) {
    return {
      monthlySalary: clampNonNegative(raw.monthlySalary ?? DEFAULT_SETTINGS.monthlySalary),
      workDaysPerMonth: clampNonNegative(raw.workDaysPerMonth ?? DEFAULT_SETTINGS.workDaysPerMonth),
      hoursPerDay: clampNonNegative(raw.hoursPerDay ?? DEFAULT_SETTINGS.hoursPerDay),
      overtimeHourlyRate: clampNonNegative(raw.overtimeHourlyRate ?? DEFAULT_SETTINGS.overtimeHourlyRate)
    };
  }

  function normalizeSession(raw = {}) {
    const phases = new Set(['idle', 'working', 'clockedOut', 'overtime', 'finished']);
    const session = {
      phase: phases.has(raw.phase) ? raw.phase : 'idle'
    };
    for (const key of SESSION_KEYS) {
      session[key] = raw[key] == null ? null : (Number.isFinite(Number(raw[key])) ? Number(raw[key]) : null);
    }
    return session;
  }

  function defaultState() {
    return {
      version: 1,
      settings: { ...DEFAULT_SETTINGS },
      session: { phase: 'idle', normalStartedAt: null, normalEndedAt: null, overtimeStartedAt: null, overtimeEndedAt: null },
      ledger: { completedEarnings: 0, completedSessions: 0 },
      language: 'en',
      currency: 'cny',
      theme: 'system',
      bigMacCounter: false,
      checkForUpdates: false,
      autoUpdate: false,
      hasLaunched: false
    };
  }

  function normalizeState(raw = {}) {
    const base = defaultState();
    const language = LANGUAGES[raw.language] ? raw.language : base.language;
    const currency = CURRENCIES[raw.currency] ? raw.currency : base.currency;
    const theme = ['system', 'light', 'dark'].includes(raw.theme) ? raw.theme : base.theme;
    const autoUpdate = Boolean(raw.autoUpdate);
    const checkForUpdates = Boolean(raw.checkForUpdates) || autoUpdate;
    const ledger = raw.ledger || {};
    return {
      version: 1,
      settings: sanitizeSettings(raw.settings),
      session: normalizeSession(raw.session),
      ledger: {
        completedEarnings: clampNonNegative(ledger.completedEarnings),
        completedSessions: Math.max(0, Math.floor(finite(ledger.completedSessions)))
      },
      language,
      currency,
      theme,
      bigMacCounter: Boolean(raw.bigMacCounter),
      checkForUpdates,
      autoUpdate,
      hasLaunched: Boolean(raw.hasLaunched)
    };
  }

  function bigMacPriceFor(currency) {
    return BIG_MAC_PRICES[currency] || BIG_MAC_PRICES.cny;
  }

  function bigMacCount(amount, currency) {
    const price = bigMacPriceFor(currency).price;
    const value = Number(amount);
    if (!Number.isFinite(value) || value <= 0 || !(price > 0)) return 0;
    const count = Math.floor(value / price);
    return Number.isSafeInteger(count) ? count : 0;
  }

  function dailyPay(settings) {
    const s = sanitizeSettings(settings);
    return s.workDaysPerMonth > 0 ? s.monthlySalary / s.workDaysPerMonth : 0;
  }

  function rates(settings) {
    const s = sanitizeSettings(settings);
    const monthlyHours = s.workDaysPerMonth * s.hoursPerDay;
    const hourly = monthlyHours > 0 ? s.monthlySalary / monthlyHours : 0;
    return {
      hourly,
      perMinute: hourly / 60,
      perSecond: hourly / 3600,
      overtimeHourly: s.overtimeHourlyRate,
      overtimePerMinute: s.overtimeHourlyRate / 60,
      overtimePerSecond: s.overtimeHourlyRate / 3600,
      overtimeMultiplier: hourly > 0 ? s.overtimeHourlyRate / hourly : 0,
      suggestedOvertimeHourly: Math.round(hourly * 1.5 * 100) / 100,
      dailyPay: dailyPay(s),
      isValid: s.monthlySalary > 0 && s.workDaysPerMonth > 0 && s.hoursPerDay > 0
    };
  }

  /// Edits the base salary and seeds overtime at 1.5x. A later overtime edit
  /// can still overwrite the stored rate directly.
  function updateMonthlySalary(settings, value) {
    const next = sanitizeSettings(settings);
    next.monthlySalary = clampNonNegative(value);
    next.overtimeHourlyRate = rates(next).suggestedOvertimeHourly;
    return next;
  }

  function snapshot(settings, session, now = Date.now()) {
    const s = sanitizeSettings(settings);
    const r = rates(s);
    const phase = normalizeSession(session).phase;
    const normalEnd = phase === 'working'
      ? now
      : (['clockedOut', 'overtime', 'finished'].includes(phase) ? session.normalEndedAt : null);
    const overtimeEnd = phase === 'overtime'
      ? now
      : (phase === 'finished' ? session.overtimeEndedAt : null);

    const normalSeconds = session.normalStartedAt != null && normalEnd != null
      ? Math.max(0, (normalEnd - session.normalStartedAt) / 1000)
      : 0;
    const overtimeSeconds = session.overtimeStartedAt != null && overtimeEnd != null
      ? Math.max(0, (overtimeEnd - session.overtimeStartedAt) / 1000)
      : 0;

    const normalEarned = normalSeconds * r.perSecond;
    const overtimeEarned = overtimeSeconds * r.overtimePerSecond;

    return {
      phase,
      normalSeconds,
      overtimeSeconds,
      normalEarned,
      overtimeEarned,
      total: normalEarned + overtimeEarned,
      totalSeconds: normalSeconds + overtimeSeconds,
      isEarning: phase === 'working' || phase === 'overtime',
      isOvertime: phase === 'overtime',
      normalHourlyRate: r.hourly,
      normalPerMinuteRate: r.perMinute,
      normalPerSecondRate: r.perSecond,
      overtimeHourlyRate: r.overtimeHourly,
      overtimePerMinuteRate: r.overtimePerMinute,
      overtimePerSecondRate: r.overtimePerSecond,
      activeHourlyRate: phase === 'overtime' ? r.overtimeHourly : r.hourly,
      activePerMinuteRate: phase === 'overtime' ? r.overtimePerMinute : r.perMinute,
      activePerSecondRate: phase === 'overtime' ? r.overtimePerSecond : r.perSecond
    };
  }

  function archive(state, amount) {
    if (!Number.isFinite(amount) || amount <= 0) return;
    state.ledger.completedEarnings = clampNonNegative(state.ledger.completedEarnings) + amount;
    state.ledger.completedSessions = Math.max(0, Math.floor(finite(state.ledger.completedSessions))) + 1;
  }

  function applyAction(state, action, now = Date.now()) {
    const current = state.session;
    switch (action) {
      case 'clockIn': {
        if (!['idle', 'clockedOut', 'finished'].includes(current.phase)) return state;
        if (current.phase === 'clockedOut' || current.phase === 'finished') {
          archive(state, snapshot(state.settings, current, now).total);
        }
        state.session = {
          phase: 'working',
          normalStartedAt: now,
          normalEndedAt: null,
          overtimeStartedAt: null,
          overtimeEndedAt: null
        };
        return state;
      }
      case 'clockOut': {
        if (current.phase !== 'working') return state;
        current.normalEndedAt = now;
        if (current.normalStartedAt == null) current.normalStartedAt = now;
        current.phase = 'clockedOut';
        return state;
      }
      case 'startOvertime': {
        if (current.phase !== 'working' && current.phase !== 'clockedOut') return state;
        if (current.phase === 'working') current.normalEndedAt = now;
        current.overtimeStartedAt = now;
        current.overtimeEndedAt = null;
        current.phase = 'overtime';
        return state;
      }
      case 'endOvertime': {
        if (current.phase !== 'overtime') return state;
        current.overtimeEndedAt = now;
        if (current.overtimeStartedAt == null) current.overtimeStartedAt = now;
        current.phase = 'finished';
        return state;
      }
      case 'resetSession':
        state.session = { phase: 'idle', normalStartedAt: null, normalEndedAt: null, overtimeStartedAt: null, overtimeEndedAt: null };
        return state;
      case 'resetEverything':
        state.ledger = { completedEarnings: 0, completedSessions: 0 };
        state.session = { phase: 'idle', normalStartedAt: null, normalEndedAt: null, overtimeStartedAt: null, overtimeEndedAt: null };
        return state;
      default:
        return state;
    }
  }

  function totalEarned(state, now = Date.now()) {
    return clampNonNegative(state.ledger.completedEarnings) + snapshot(state.settings, state.session, now).total;
  }

  function hasRecordedTime(session) {
    return session.normalStartedAt != null || session.overtimeStartedAt != null;
  }

  function canClockIn(session) {
    return ['idle', 'clockedOut', 'finished'].includes(session.phase);
  }
  function canClockOut(session) { return session.phase === 'working'; }
  function canStartOvertime(session) { return session.phase === 'clockedOut'; }
  function canEndOvertime(session) { return session.phase === 'overtime'; }

  return {
    CURRENCIES,
    LANGUAGES,
    DEFAULT_SETTINGS,
    BIG_MAC_PRICES,
    defaultState,
    normalizeState,
    sanitizeSettings,
    normalizeSession,
    bigMacPriceFor,
    bigMacCount,
    rates,
    updateMonthlySalary,
    snapshot,
    applyAction,
    totalEarned,
    hasRecordedTime,
    canClockIn,
    canClockOut,
    canStartOvertime,
    canEndOvertime,
    archive
  };
});
