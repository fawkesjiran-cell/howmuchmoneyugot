'use strict';

const Core = window.Core;
const Format = window.Format;
const I18N = window.I18N;

const $ = id => document.getElementById(id);
const PHASE_KEYS = {
  idle: 'phaseIdle',
  working: 'phaseWorking',
  clockedOut: 'phaseClockedOut',
  overtime: 'phaseOvertime',
  finished: 'phaseFinished'
};
const PHASE_ACTION = {
  idle: 'clockIn',
  working: 'clockOut',
  clockedOut: 'startOvertime',
  overtime: 'endOvertime',
  finished: 'clockIn'
};

let state = Core.defaultState();
let currentView = 'main';
let captureMode = false;
let demoMode = null;
let saveTimer = null;
let toastTimer = null;
let fire = null;
let lastTrayTitle = '';
let lastTrayTooltip = '';

const media = window.matchMedia('(prefers-color-scheme: dark)');
const bridge = window.desktop || null;

function t(key, ...args) {
  return I18N.t(state.language, key, ...args);
}

function unit() {
  return Core.CURRENCIES[state.currency] || Core.CURRENCIES.cny;
}

function resolvedTheme() {
  if (state.theme === 'system') return media.matches ? 'dark' : 'light';
  return state.theme === 'dark' ? 'dark' : 'light';
}

function themeKey(theme = state.theme) {
  return theme === 'light' ? 'appearanceLight' : theme === 'dark' ? 'appearanceDark' : 'appearanceSystem';
}

function nextTheme() {
  return state.theme === 'system' ? 'light' : state.theme === 'light' ? 'dark' : 'system';
}

function applyTheme() {
  const theme = resolvedTheme();
  document.documentElement.dataset.theme = theme;
  const icon = state.theme === 'system' ? 'i-system' : state.theme === 'light' ? 'i-sun' : 'i-moon';
  $('themeIcon').setAttribute('href', `#${icon}`);
  const help = t('appearance', t(themeKey()));
  $('themeButton').title = help;
  $('themeButton').setAttribute('aria-label', help);
}

function saveState() {
  if (!bridge || captureMode || demoMode) return;
  bridge.saveState(state).catch(() => {});
}

function scheduleSave() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(saveState, 240);
}

function formatInput(value) {
  return new Intl.NumberFormat(Format.localeFor(state.language), {
    maximumFractionDigits: 2
  }).format(Number.isFinite(value) ? value : 0);
}

function buildDemo(kind) {
  const next = Core.normalizeState(Core.defaultState());
  next.settings = { monthlySalary: 22000, workDaysPerMonth: 22, hoursPerDay: 8, overtimeHourlyRate: 187.5 };
  next.ledger = { completedEarnings: 1280.4, completedSessions: 4 };
  next.language = state.language;
  next.currency = state.currency;
  next.theme = state.theme;
  const now = Date.now();
  const h = 3600_000;
  const m = 60_000;
  switch (kind) {
    case 'idle':
      next.session = { phase: 'idle', normalStartedAt: null, normalEndedAt: null, overtimeStartedAt: null, overtimeEndedAt: null };
      break;
    case 'working':
      next.session = { phase: 'working', normalStartedAt: now - (3 * h + 12 * m + 24_000), normalEndedAt: null, overtimeStartedAt: null, overtimeEndedAt: null };
      break;
    case 'clockedout':
      next.session = { phase: 'clockedOut', normalStartedAt: now - 8 * h, normalEndedAt: now - h, overtimeStartedAt: null, overtimeEndedAt: null };
      break;
    case 'finished':
      next.session = { phase: 'finished', normalStartedAt: now - 9 * h, normalEndedAt: now - 2 * h, overtimeStartedAt: now - 2 * h, overtimeEndedAt: now - 30 * m };
      break;
    case 'overtime':
    default:
      next.session = { phase: 'overtime', normalStartedAt: now - 5 * h, normalEndedAt: now - 2 * h, overtimeStartedAt: now - 1.5 * h, overtimeEndedAt: null };
      break;
  }
  return next;
}

function showText(el, value) {
  if (el && el.textContent !== value) el.textContent = value;
}

function setClass(el, className, enabled) {
  if (el) el.classList.toggle(className, enabled);
}

function showToast(message) {
  const el = $('toast');
  if (!el) return;
  el.textContent = message;
  el.hidden = false;
  requestAnimationFrame(() => el.classList.add('visible'));
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    el.classList.remove('visible');
    setTimeout(() => { el.hidden = true; }, 160);
  }, 1350);
}

function setAction(id, labelId, label, enabled, solid, hint = false) {
  const el = $(id);
  if (!el) return;
  el.disabled = !enabled;
  el.classList.toggle('solid', enabled && solid);
  el.classList.toggle('hint', hint);
  showText($(labelId), label);
}

function setRailStop(id, stateName, time, overtime = false) {
  const el = $(id);
  if (!el) return;
  el.classList.remove('future', 'active', 'complete', 'ot');
  el.classList.add(stateName);
  if (overtime) el.classList.add('ot');
  const timeEl = el.querySelector('.stime');
  showText(timeEl, time || '--:--');
}

function pluralCurrency(code) {
  return code;
}

function renderChrome() {
  document.documentElement.lang = state.language === 'zh-Hans' ? 'zh-CN' : 'en';
  const data = unit();
  showText($('logoMark'), data.symbol);
  showText($('currencySymbol'), data.symbol);
  showText($('thisSessionLabel'), t('thisSession'));
  $('resetButton').disabled = !Core.hasRecordedTime(state.session);
  $('resetButton').title = t('resetSession');
  $('resetButton').setAttribute('aria-label', t('resetSession'));
  $('settingsButton').title = t('settings');
  $('settingsButton').setAttribute('aria-label', t('settings'));
  $('settingsTitle').textContent = t('settingsTitle');
  $('doneButton').textContent = t('doneAction');
  $('backButton').title = t('back');
  $('backButton').setAttribute('aria-label', t('back'));
  $('languageLabel').textContent = t('language');
  $('currencyLabel').textContent = t('currency');
  $('prefsLabel').textContent = t('preferences');
  $('payLabel').textContent = t('pay');
  $('savedHint').textContent = t('savedAsYouType');
  $('salaryLabel').textContent = t('monthlySalary');
  $('workdaysLabel').textContent = t('workdays');
  $('hoursLabel').textContent = t('hours');
  $('overtimeLabel').textContent = t('overtimeRate');
  $('ratesLabel').textContent = t('rates');
  $('dataLabel').textContent = t('data');
  $('resetTitle').textContent = t('resetEverything');
  $('clearButton').textContent = t('clear');
  $('actionClockInLabel').textContent = t('clockIn');
  $('actionClockOutLabel').textContent = t('clockOut');
  $('actionOvertimeLabel').textContent = t('startOvertime');
  $('actionFinishLabel').textContent = t('endOvertime');
  $('railInLabel').textContent = t('in');
  $('railOutLabel').textContent = t('out');
  $('railOTLabel').textContent = t('ot');
  $('railDoneLabel').textContent = t('done');
  $('rateSecLabel').textContent = t('perSecond');
  $('rateMinLabel').textContent = t('perMinute');
  $('rateHourLabel').textContent = t('perHour');
  $('setRateSecLabel').textContent = t('perSecond');
  $('setRateMinLabel').textContent = t('perMinute');
  $('setRateHourLabel').textContent = t('perHour');
  $('salaryInput').setAttribute('aria-label', t('monthlySalary'));
  $('workdaysInput').setAttribute('aria-label', t('workdays'));
  $('hoursInput').setAttribute('aria-label', t('hours'));
  $('overtimeInput').setAttribute('aria-label', t('overtimeRate'));
  $('settingsView').hidden = currentView !== 'settings';
  $('mainView').hidden = currentView !== 'main';
  applyTheme();
}

function populateSelects() {
  const language = $('languageSelect');
  if (language.dataset.language !== state.language) {
    language.dataset.language = state.language;
    language.replaceChildren();
    for (const [value, meta] of Object.entries(Core.LANGUAGES)) {
      const option = document.createElement('option');
      option.value = value;
      option.textContent = meta.nativeName;
      language.append(option);
    }
  }
  language.value = state.language;

  const currency = $('currencySelect');
  if (currency.dataset.language !== state.language) {
    currency.dataset.language = state.language;
    currency.replaceChildren();
    for (const [value, meta] of Object.entries(Core.CURRENCIES)) {
      const option = document.createElement('option');
      option.value = value;
      option.textContent = `${state.language === 'zh-Hans' ? meta.zh : meta.en} · ${meta.code}`;
      currency.append(option);
    }
  }
  currency.value = state.currency;
}

function renderSettings() {
  populateSelects();
  const data = unit();
  const r = Core.rates(state.settings);
  const f = (value, digits) => Format.amount(value, state.language, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits
  });
  const suffix = {
    salary: `${data.code}/${t('perMonth')}`,
    days: t('days'),
    hours: t('hoursUnit'),
    overtime: `${data.code}/${t('perHourUnit')}`
  };
  showText($('salarySuffix'), suffix.salary);
  showText($('workdaysSuffix'), suffix.days);
  showText($('hoursSuffix'), suffix.hours);
  showText($('overtimeSuffix'), suffix.overtime);
  showText($('setRateHour'), `${data.symbol}${f(r.hourly, 2)}`);
  showText($('setRateMin'), `${data.symbol}${f(r.perMinute, 3)}`);
  showText($('setRateSec'), `${data.symbol}${f(r.perSecond, 4)}`);

  const inputs = [
    ['salaryInput', 'monthlySalary'],
    ['workdaysInput', 'workDaysPerMonth'],
    ['hoursInput', 'hoursPerDay'],
    ['overtimeInput', 'overtimeHourlyRate']
  ];
  for (const [id, key] of inputs) {
    const input = $(id);
    if (document.activeElement !== input) input.value = formatInput(state.settings[key]);
    input.classList.toggle('invalid', !(state.settings[key] > 0) && ['monthlySalary', 'workDaysPerMonth', 'hoursPerDay'].includes(key));
  }

  const total = Core.totalEarned(state, Date.now());
  $('resetCaption').textContent = t('resetCaption', Format.money(total, state.currency, state.language));
  $('clearButton').disabled = total <= 0;
}

function renderMain() {
  const now = Date.now();
  const snap = Core.snapshot(state.settings, state.session, now);
  const total = Core.totalEarned(state, now);
  const data = unit();
  const money = Format.money(snap.total, state.currency, state.language);
  const allTime = Format.money(total, state.currency, state.language);
  const r = Core.rates(state.settings);

  $('statusDot').className = `status-dot ${snap.phase}`;
  showText($('phaseText'), t(PHASE_KEYS[snap.phase] || 'phaseIdle'));
  $('phaseText').classList.toggle('overtime', snap.isOvertime);
  $('otChip').hidden = !snap.isOvertime;
  if (snap.isOvertime) showText($('otChip'), `×${r.overtimeMultiplier.toFixed(1)}`);

  $('currencySymbol').classList.toggle('overtime', snap.isOvertime);
  $('normalAmount').hidden = snap.isOvertime;
  $('fireCanvas').hidden = !snap.isOvertime;
  if (snap.isOvertime && currentView === 'main') {
    $('normalAmount').textContent = '';
    if (!fire) fire = new window.FireRenderer($('fireCanvas'));
    fire.setAmount(Format.amount(snap.total, state.language), resolvedTheme());
    fire.start();
  } else {
    if (fire) fire.stop();
    if (!snap.isOvertime) $('normalAmount').textContent = Format.amount(snap.total, state.language);
  }

  showText($('sessionTime'), Format.duration(snap.totalSeconds));
  showText($('allTime'), `${t('allTime')} ${allTime}`);
  showText($('targetLabel'), `${t('dailyTarget')} · ${Format.money(r.dailyPay, state.currency, state.language)}`);
  const percent = r.dailyPay > 0 ? Math.min(999, Math.round(snap.total / r.dailyPay * 100)) : 0;
  showText($('targetPercent'), `${percent}%`);
  $('targetPercent').classList.toggle('overtime', snap.isOvertime);
  $('targetFill').style.width = `${Math.min(100, Math.max(0, percent))}%`;

  const active = snap.isOvertime;
  showText($('rateSecLabel'), t('perSecond'));
  showText($('rateMinLabel'), t('perMinute'));
  showText($('rateHourLabel'), t('perHour'));
  const decimals = [4, 3, 2];
  const values = [snap.activePerSecondRate, snap.activePerMinuteRate, snap.activeHourlyRate];
  const valueIds = ['rateSec', 'rateMin', 'rateHour'];
  const symbolIds = ['rateSecSymbol', 'rateMinSymbol', 'rateHourSymbol'];
  for (let i = 0; i < 3; i += 1) {
    showText($(symbolIds[i]), data.symbol);
    showText($(valueIds[i]), Format.amount(values[i], state.language, {
      minimumFractionDigits: decimals[i],
      maximumFractionDigits: decimals[i]
    }));
    $(valueIds[i]).style.color = active ? 'var(--action)' : 'var(--ink)';
    if (active) $(valueIds[i]).style.color = '#8A5A00';
  }
  if (active && resolvedTheme() === 'dark') {
    for (const id of valueIds) $(id).style.color = 'var(--action)';
  }

  const canIn = Core.canClockIn(state.session);
  const canOut = Core.canClockOut(state.session);
  const canStart = Core.canStartOvertime(state.session);
  const canFinish = Core.canEndOvertime(state.session);
  setAction('actionClockIn', 'actionClockInLabel', t('clockIn'), canIn, canIn && state.session.phase !== 'clockedOut');
  setAction('actionClockOut', 'actionClockOutLabel', t('clockOut'), canOut, canOut);
  setAction('actionOvertime', 'actionOvertimeLabel', t('startOvertime'), canStart, canStart, state.session.phase === 'working');
  setAction('actionFinish', 'actionFinishLabel', t('endOvertime'), canFinish, canFinish);

  const progress = { idle: 0, working: 0, clockedOut: 1 / 3, overtime: 2 / 3, finished: 1 }[snap.phase] || 0;
  const regular = Math.min(progress, 1 / 3) / (1 / 3) * 25;
  const overtime = Math.max(0, progress - 1 / 3) / (2 / 3) * 50;
  $('railRegularFill').hidden = regular <= 0;
  $('railRegularFill').style.width = `${regular}%`;
  $('railOvertimeFill').hidden = overtime <= 0;
  $('railOvertimeFill').style.width = `${overtime}%`;

  const phase = snap.phase;
  const inState = phase === 'idle' ? 'future' : phase === 'working' ? 'active' : 'complete';
  const outState = ['idle', 'working'].includes(phase) ? 'future' : phase === 'clockedOut' ? 'active' : 'complete';
  const otState = ['idle', 'working', 'clockedOut'].includes(phase) ? 'future' : phase === 'overtime' ? 'active' : 'complete';
  const doneState = phase === 'finished' ? 'active' : 'future';
  setRailStop('railIn', inState, Format.clock(state.session.normalStartedAt));
  setRailStop('railOut', outState, Format.clock(state.session.normalEndedAt));
  setRailStop('railOT', otState, Format.clock(state.session.overtimeStartedAt), true);
  setRailStop('railDone', doneState, Format.clock(state.session.overtimeEndedAt));

  if (bridge) {
    const title = allTime;
    const tooltip = `${t(PHASE_KEYS[phase] || 'phaseIdle')} · ${money} · ${allTime}`;
    if (title !== lastTrayTitle || tooltip !== lastTrayTooltip) {
      lastTrayTitle = title;
      lastTrayTooltip = tooltip;
      bridge.updateTray({ title, tooltip });
    }
  }
}

function render() {
  renderChrome();
  renderMain();
  renderSettings();
}

function setView(view) {
  currentView = view;
  if (view === 'settings') {
    $('settingsScroll').scrollTop = 0;
  }
  render();
}

async function confirmSessionReset() {
  if (!Core.hasRecordedTime(state.session)) return;
  const snap = Core.snapshot(state.settings, state.session, Date.now());
  const ok = bridge
    ? await bridge.confirm({
        title: t('resetSessionTitle'),
        message: t('resetSessionMessage', Format.money(snap.total, state.currency, state.language)),
        confirmLabel: t('reset'),
        cancelLabel: t('cancel')
      })
    : window.confirm(t('resetSessionTitle'));
  if (!ok) return;
  Core.applyAction(state, 'resetSession');
  saveState();
  render();
}

async function confirmEverythingReset() {
  const now = Date.now();
  const total = Core.totalEarned(state, now);
  if (total <= 0) return;
  const current = Core.snapshot(state.settings, state.session, now).total;
  const ok = bridge
    ? await bridge.confirm({
        title: t('resetEverythingTitle'),
        message: t('resetEverythingMessage', Format.money(total, state.currency, state.language), Format.money(current, state.currency, state.language)),
        confirmLabel: t('resetAll'),
        cancelLabel: t('cancel')
      })
    : window.confirm(t('resetEverythingTitle'));
  if (!ok) return;
  Core.applyAction(state, 'resetEverything');
  saveState();
  render();
}

function wireInput(id, key) {
  const input = $(id);
  input.addEventListener('focus', () => {
    input.value = String(state.settings[key]);
    requestAnimationFrame(() => input.select());
  });
  input.addEventListener('input', () => {
    const raw = input.value.replace(/,/g, '').trim();
    const value = Number(raw);
    if (!raw || !Number.isFinite(value) || value < 0) {
      input.classList.add('invalid');
      return;
    }
    input.classList.remove('invalid');
    state.settings[key] = value;
    scheduleSave();
    render();
  });
  input.addEventListener('blur', () => {
    input.value = formatInput(state.settings[key]);
    input.classList.remove('invalid');
    saveState();
    render();
  });
}

function cycleTheme() {
  state.theme = nextTheme();
  if (bridge) bridge.setTheme(state.theme).catch(() => {});
  applyTheme();
  saveState();
  showToast(t('appearance', t(themeKey())));
  render();
}

function handleCommand(command) {
  if (command === 'reset-session') {
    confirmSessionReset();
  } else if (command === 'open-settings') {
    setView('settings');
  }
}

function bind() {
  $('themeButton').addEventListener('click', cycleTheme);
  $('resetButton').addEventListener('click', confirmSessionReset);
  $('settingsButton').addEventListener('click', () => setView('settings'));
  $('backButton').addEventListener('click', () => setView('main'));
  $('doneButton').addEventListener('click', () => setView('main'));
  $('actionClockIn').addEventListener('click', () => { Core.applyAction(state, 'clockIn'); saveState(); render(); });
  $('actionClockOut').addEventListener('click', () => { Core.applyAction(state, 'clockOut'); saveState(); render(); });
  $('actionOvertime').addEventListener('click', () => { Core.applyAction(state, 'startOvertime'); saveState(); render(); });
  $('actionFinish').addEventListener('click', () => { Core.applyAction(state, 'endOvertime'); saveState(); render(); });
  $('clearButton').addEventListener('click', confirmEverythingReset);

  $('languageSelect').addEventListener('change', event => {
    state.language = event.target.value;
    saveState();
    render();
  });
  $('currencySelect').addEventListener('change', event => {
    state.currency = event.target.value;
    saveState();
    render();
  });
  wireInput('salaryInput', 'monthlySalary');
  wireInput('workdaysInput', 'workDaysPerMonth');
  wireInput('hoursInput', 'hoursPerDay');
  wireInput('overtimeInput', 'overtimeHourlyRate');

  media.addEventListener('change', () => {
    if (state.theme === 'system') {
      applyTheme();
      render();
    }
  });
  window.addEventListener('keydown', event => {
    if (event.key === 'Escape') bridge?.hide();
  });
  if (bridge) {
    bridge.onThemeChanged(() => {
      applyTheme();
      render();
    });
    bridge.onCommand(handleCommand);
  }
}

async function init() {
  let loaded = null;
  if (bridge) {
    try { loaded = await bridge.getState(); } catch {}
  }
  state = Core.normalizeState(loaded || Core.defaultState());
  const params = new URLSearchParams(location.search);
  captureMode = params.get('capture') === '1';
  if (params.get('theme') && ['system', 'light', 'dark'].includes(params.get('theme'))) {
    state.theme = params.get('theme');
  }
  if (params.get('lang') && Core.LANGUAGES[params.get('lang')]) {
    state.language = params.get('lang');
  }
  if (params.get('demo')) {
    const demo = params.get('demo');
    if (['idle', 'working', 'clockedout', 'finished', 'overtime'].includes(demo)) {
      demoMode = demo;
      state = buildDemo(demo);
      if (params.get('theme')) state.theme = params.get('theme');
    }
  }
  if (params.get('screen') === 'settings') currentView = 'settings';
  bind();
  applyTheme();
  render();
  setInterval(render, 200);
  document.fonts.ready.then(() => {
    if (fire) fire.layout();
    render();
    if (params.get('scroll') === '1') {
      const scroll = $('settingsScroll');
      requestAnimationFrame(() => { scroll.scrollTop = scroll.scrollHeight; });
    }
  });
}

init();
