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

// Fixed-size burgers live on a 120 x 46 ledge. They spawn in a narrow central
// band, collide with each other and can be knocked off the wider ledge; burgers
// that leave it fall out of the panel. The hover count is independent of that.
const BIGMAC_FIELD_WIDTH = 130;
const BIGMAC_FIELD_HEIGHT = 104;
const BIGMAC_RADIUS = 7.5;
const BIGMAC_PLATFORM_Y = 92;
const BIGMAC_PLATFORM_MIN = 19;
const BIGMAC_PLATFORM_MAX = 111;
const BIGMAC_FALL_MIN = 10;
const BIGMAC_FALL_MAX = 120;
const BIGMAC_SPAWN_MIN = 39;
const BIGMAC_SPAWN_MAX = 91;
const BIGMAC_GRAVITY = 900;
const BIGMAC_MAX_BODIES = 200;
const BIGMAC_INITIAL_SPAWN_CAP = 36;

let state = Core.defaultState();
let currentView = 'main';
let captureMode = false;
let demoMode = null;
let saveTimer = null;
let toastTimer = null;
let fire = null;
let lastTrayTitle = '';
let lastTrayTooltip = '';
let lastBigMacCount = null;
let updateStatus = { state: 'disabled', currentVersion: '' };
let offlineMode = false;
let updatePreviewMode = false;
let bigmacSpans = new Map();
let bigmacBodies = [];
let bigmacNextId = 0;
let bigmacLogicalCount = 0;
let bigmacPileInitialized = false;
let bigmacRaf = 0;
let bigmacLastTime = 0;
let bigmacAccumulator = 0;
let bigmacQuietFrames = 0;
let bigmacStartTime = 0;
let bigMacFlashTimer = null;
let bigMacFlashToken = 0;

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
  next.bigMacCounter = state.bigMacCounter;
  next.checkForUpdates = state.checkForUpdates;
  next.autoUpdate = state.autoUpdate;
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

function bigmacOpacity(body) {
  const fadeStart = BIGMAC_PLATFORM_Y + 2;
  if (body.y <= fadeStart) return 1;
  const remaining = (BIGMAC_FIELD_HEIGHT + BIGMAC_RADIUS - body.y)
    / (BIGMAC_FIELD_HEIGHT + BIGMAC_RADIUS - fadeStart);
  return Math.max(0, Math.min(1, remaining));
}

function bigmacCreateSpan(body) {
  const pile = $('bigmacPile');
  if (!pile) return null;
  const span = document.createElement('span');
  span.className = 'bigmac-burger';
  span.textContent = '🍔';
  span.setAttribute('aria-hidden', 'true');
  span.style.transform = `translate3d(${body.x - BIGMAC_RADIUS}px, ${body.y - BIGMAC_RADIUS}px, 0) rotate(${body.angle}deg)`;
  span.style.opacity = String(bigmacOpacity(body));
  pile.appendChild(span);
  return span;
}

function bigmacRender() {
  const liveIds = new Set();

  for (const body of bigmacBodies) {
    liveIds.add(body.id);
    let span = bigmacSpans.get(body.id);
    if (!span) {
      span = bigmacCreateSpan(body);
      if (!span) continue;
      bigmacSpans.set(body.id, span);
    }
    span.style.transform = `translate3d(${body.x - BIGMAC_RADIUS}px, ${body.y - BIGMAC_RADIUS}px, 0) rotate(${body.angle}deg)`;
    span.style.opacity = String(bigmacOpacity(body));
  }

  for (const [id, span] of [...bigmacSpans]) {
    if (!liveIds.has(id)) {
      span.remove();
      bigmacSpans.delete(id);
    }
  }
}

function bigmacSpawn() {
  if (bigmacBodies.length >= BIGMAC_MAX_BODIES) return;

  const id = bigmacNextId;
  bigmacNextId += 1;
  bigmacBodies.push({
    id,
    x: BIGMAC_SPAWN_MIN + Math.random() * (BIGMAC_SPAWN_MAX - BIGMAC_SPAWN_MIN),
    y: -BIGMAC_RADIUS - 4 - Math.random() * 12,
    vx: (Math.random() - 0.5) * 60,
    vy: 0,
    angle: (Math.random() - 0.5) * 40,
    spin: (Math.random() - 0.5) * 320
  });
}

function bigmacWake() {
  bigmacQuietFrames = 0;
  bigmacStartTime = performance.now();

  if (!bigmacRaf) {
    bigmacLastTime = performance.now();
    bigmacAccumulator = 0;
    bigmacRaf = requestAnimationFrame(bigmacFrame);
  }
}

function bigmacResolvePlatform(bodies, index) {
  const body = bodies[index];
  if (body.x < BIGMAC_PLATFORM_MIN || body.x > BIGMAC_PLATFORM_MAX) return;
  if (body.y < BIGMAC_PLATFORM_Y - BIGMAC_RADIUS || body.y > BIGMAC_PLATFORM_Y) return;

  body.y = BIGMAC_PLATFORM_Y - BIGMAC_RADIUS;
  if (body.vy > 0) {
    body.vy = -body.vy * 0.06;
    if (Math.abs(body.vy) < 12) body.vy = 0;
  }
  body.vx *= 0.965;
  const targetSpin = body.vx / BIGMAC_RADIUS;
  body.spin += (targetSpin - body.spin) * 0.10;
  body.spin *= 0.94;
  if (Math.abs(body.vx) < 0.5) body.vx = 0;
}

function bigmacResolvePair(bodies, i, j) {
  const minDist = BIGMAC_RADIUS * 2;
  let dx = bodies[j].x - bodies[i].x;
  let dy = bodies[j].y - bodies[i].y;
  const distanceSquared = dx * dx + dy * dy;
  if (distanceSquared >= minDist * minDist) return;

  let distance = Math.sqrt(distanceSquared);
  if (distance < 0.0001) {
    dx = 1;
    dy = 0;
    distance = 0.0001;
  }

  const nx = dx / distance;
  const ny = dy / distance;
  const push = (minDist - distance) * 0.5;
  bodies[i].x -= nx * push;
  bodies[i].y -= ny * push;
  bodies[j].x += nx * push;
  bodies[j].y += ny * push;

  const rvx = bodies[j].vx - bodies[i].vx;
  const rvy = bodies[j].vy - bodies[i].vy;

  const normalVelocity = rvx * nx + rvy * ny;
  if (normalVelocity < 0) {
    const impulse = -(1 + 0.06) * normalVelocity * 0.5;
    bodies[i].vx -= impulse * nx;
    bodies[i].vy -= impulse * ny;
    bodies[j].vx += impulse * nx;
    bodies[j].vy += impulse * ny;
  }

  const tx = -ny;
  const ty = nx;
  const tangentVelocity = rvx * tx + rvy * ty;
  const tangentImpulse = -tangentVelocity * 0.38 * 0.5;
  bodies[i].vx -= tangentImpulse * tx;
  bodies[i].vy -= tangentImpulse * ty;
  bodies[j].vx += tangentImpulse * tx;
  bodies[j].vy += tangentImpulse * ty;

  bodies[i].spin += tangentVelocity * 0.012;
  bodies[j].spin -= tangentVelocity * 0.012;
}

function bigmacStep(bodies, dt) {
  for (const body of bodies) {
    body.vy += BIGMAC_GRAVITY * dt;
    body.x += body.vx * dt;
    body.y += body.vy * dt;
    body.angle += body.spin * dt;
    body.spin *= 0.97;
    if (Math.abs(body.spin) < 2) body.spin = 0;
  }

  for (let iteration = 0; iteration < 5; iteration += 1) {
    for (let index = 0; index < bodies.length; index += 1) {
      bigmacResolvePlatform(bodies, index);
    }
    for (let i = 0; i < bodies.length - 1; i += 1) {
      for (let j = i + 1; j < bodies.length; j += 1) {
        bigmacResolvePair(bodies, i, j);
      }
    }
  }

  for (const body of bodies) {
    if (body.x < BIGMAC_FALL_MIN) {
      body.x = BIGMAC_FALL_MIN;
      body.vx = 0;
    } else if (body.x > BIGMAC_FALL_MAX) {
      body.x = BIGMAC_FALL_MAX;
      body.vx = 0;
    }
  }

  for (let index = bodies.length - 1; index >= 0; index -= 1) {
    if (bodies[index].y - BIGMAC_RADIUS > BIGMAC_FIELD_HEIGHT) {
      bodies.splice(index, 1);
    }
  }
}

function bigmacQuiet() {
  return bigmacBodies.every(body => (
    Math.abs(body.vx) < 4
      && Math.abs(body.vy) < 4
      && Math.abs(body.spin) < 10
  ));
}

function bigmacFinish() {
  if (bigmacRaf) cancelAnimationFrame(bigmacRaf);
  bigmacRaf = 0;
  for (const body of bigmacBodies) {
    body.vx = 0;
    body.vy = 0;
    body.spin = 0;
  }
  bigmacRender();
}

function bigmacFrame(now) {
  if (!bigmacRaf) return;

  const frameTime = Math.min(1 / 30, Math.max(1 / 120, (now - bigmacLastTime) / 1000));
  bigmacLastTime = now;
  bigmacAccumulator += frameTime;

  const fixedStep = 1 / 120;
  let steps = 0;
  while (bigmacAccumulator >= fixedStep && steps < 4) {
    bigmacStep(bigmacBodies, fixedStep);
    bigmacAccumulator -= fixedStep;
    steps += 1;
  }

  bigmacRender();

  if (bigmacQuiet()) {
    bigmacQuietFrames += 1;
  } else {
    bigmacQuietFrames = 0;
  }

  if (bigmacQuietFrames >= 30 || now - bigmacStartTime > 6000) {
    bigmacFinish();
    return;
  }

  bigmacRaf = requestAnimationFrame(bigmacFrame);
}

function bigmacStop() {
  if (bigmacRaf) cancelAnimationFrame(bigmacRaf);
  bigmacRaf = 0;
}

function bigmacClear() {
  bigmacStop();
  bigmacBodies = [];
  bigmacSpans.forEach(span => span.remove());
  bigmacSpans.clear();
  bigmacNextId = 0;
  bigmacLogicalCount = 0;
  bigmacPileInitialized = false;
  bigmacQuietFrames = 0;
}

function bigmacSetCount(count) {
  const previous = bigmacLogicalCount;
  const firstSync = !bigmacPileInitialized;
  bigmacLogicalCount = count;
  bigmacPileInitialized = true;

  if (count <= 0) {
    bigmacStop();
    bigmacBodies = [];
    bigmacSpans.forEach(span => span.remove());
    bigmacSpans.clear();
    return;
  }

  if (firstSync) {
    const visible = Math.min(count, BIGMAC_INITIAL_SPAWN_CAP);
    for (let index = 0; index < visible; index += 1) {
      bigmacSpawn();
    }
  } else if (count > previous) {
    const available = Math.max(0, BIGMAC_MAX_BODIES - bigmacBodies.length);
    const toSpawn = Math.min(count - previous, available, 8);
    for (let index = 0; index < toSpawn; index += 1) {
      bigmacSpawn();
    }
  }

  if (bigmacBodies.length) bigmacWake();
}

function renderBigMacField(count, enabled) {
  const field = $('bigmacField');
  if (!field) return;

  if (!enabled) {
    field.hidden = true;
    bigmacClear();
    return;
  }

  field.hidden = false;

  if (!bigmacPileInitialized || count !== bigmacLogicalCount) {
    bigmacSetCount(count);
  }

  const hover = $('bigmacHover');
  if (hover) hover.textContent = t('bigMacHoverCount', count);
  field.setAttribute('aria-label', t('bigMacA11y', count));
}

function playBigMacFlash() {
  const el = $('bigmacFlash');
  if (!el) return;
  const token = ++bigMacFlashToken;
  clearTimeout(bigMacFlashTimer);
  el.hidden = false;
  el.classList.remove('run');
  void el.offsetWidth;
  el.classList.add('run');
  bigMacFlashTimer = setTimeout(() => {
    if (token !== bigMacFlashToken) return;
    el.classList.remove('run');
    el.hidden = true;
  }, 820);
}

function syncBigMacAnimations(count, enabled) {
  if (!enabled) {
    lastBigMacCount = null;
    renderBigMacField(0, false);
    return;
  }

  const previous = lastBigMacCount;
  const increased = previous != null && count > previous;
  renderBigMacField(count, true);
  lastBigMacCount = count;

  if (increased) playBigMacFlash();
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

function renderUpdatePrompt() {
  const logo = $('logoMark');
  const button = $('updatePromptButton');
  if (!logo || !button) return;

  const version = updateStatus.version || updateStatus.currentVersion || '';
  const active = !offlineMode
    && Boolean(state.checkForUpdates)
    && ['available', 'downloaded', 'downloading', 'preparing', 'installing'].includes(updateStatus.state);
  const busy = ['downloading', 'preparing', 'installing'].includes(updateStatus.state);

  logo.hidden = active;
  button.hidden = !active;

  if (!active) {
    button.classList.remove('busy');
    button.disabled = false;
    return;
  }

  const title = t('updatePrompt', version);
  const hint = t('updatePromptHint', version);
  button.title = hint;
  button.setAttribute('aria-label', title);
  button.setAttribute('aria-description', hint);
  button.classList.toggle('busy', busy);
  button.disabled = busy;
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
  $('bigmacTitle').textContent = t('bigMacTitle');
  $('bigmacToggle').checked = Boolean(state.bigMacCounter);
  $('bigmacToggle').setAttribute('aria-label', t('bigMacTitle'));
  $('bigmacToggle').title = t('bigMacHint');
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
  renderUpdatePrompt();
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

function updateStatusText() {
  switch (updateStatus.state) {
    case 'disabled': return t('updateStatusDisabled');
    case 'idle': return t('updateStatusIdle');
    case 'checking': return t('updateStatusChecking');
    case 'up-to-date': return t('updateStatusUpToDate');
    case 'available': return t('updateStatusAvailable', updateStatus.version || updateStatus.currentVersion || '');
    case 'downloading':
      return t('updateStatusDownloading', updateStatus.version || updateStatus.currentVersion || '');
    case 'downloaded':
      return t('updateStatusDownloaded', updateStatus.version || updateStatus.currentVersion || '');
    case 'installing': return t('updateStatusInstalling');
    case 'unavailable': return t('updateStatusUnavailable');
    case 'error':
    default: return t('updateStatusError');
  }
}

function renderUpdateSettings() {
  const section = $('updatesSection');
  if (section) section.hidden = offlineMode;
  if (offlineMode) return;

  const version = updateStatus.currentVersion || '';
  $('updatesLabel').textContent = t('updates');
  $('updateVersion').textContent = version ? `v${version}` : '';
  $('checkUpdatesTitle').textContent = t('updateCheckAuto');
  $('autoUpdateTitle').textContent = t('updateAutoInstall');
  $('checkUpdatesToggle').checked = Boolean(state.checkForUpdates);
  $('autoUpdateToggle').checked = Boolean(state.autoUpdate);

  const busy = ['checking', 'downloading', 'installing'].includes(updateStatus.state);
  const failed = updateStatus.state === 'error';
  const unavailable = updateStatus.state === 'unavailable';
  const action = (updateStatus.state === 'available' || updateStatus.state === 'downloaded')
    ? 'install'
    : (failed ? 'retry' : 'check');

  $('updateStatus').textContent = updateStatusText();
  $('updateStatus').classList.toggle('error', failed);
  $('updateStatusDot').className = `update-dot${failed ? ' error' : ''}${busy ? ' busy' : ''}${updateStatus.state === 'available' ? ' available' : ''}`;

  const button = $('updateAction');
  button.textContent = action === 'install'
    ? t('updateInstallAction')
    : (action === 'retry' ? t('updateRetryAction') : t('updateCheckAction'));
  button.disabled = busy || unavailable;
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
  renderUpdateSettings();
}

function renderMain() {
  const now = Date.now();
  const snap = Core.snapshot(state.settings, state.session, now);
  const total = Core.totalEarned(state, now);
  const data = unit();
  const money = Format.money(snap.total, state.currency, state.language);
  const allTime = Format.money(total, state.currency, state.language);
  const r = Core.rates(state.settings);

  const bigMacOn = Boolean(state.bigMacCounter);
  const bigMacCount = bigMacOn ? Core.bigMacCount(snap.total, state.currency) : 0;
  $('amountRow').classList.toggle('has-bigmac', bigMacOn);
  if (bigMacOn) {
    const price = Core.bigMacPriceFor(state.currency);
    const priceText = Format.money(price.price, state.currency, state.language);
    const country = state.language === 'zh-Hans' ? price.countryZh : price.country;
    $('bigmacField').setAttribute(
      'aria-description',
      t('bigMacPrice', country, priceText)
    );
  }
  syncBigMacAnimations(bigMacCount, bigMacOn);

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
    const baseTooltip = `${t(PHASE_KEYS[phase] || 'phaseIdle')} · ${money} · ${allTime}`;
    const tooltip = bigMacOn
      ? `${baseTooltip} · ${t('bigMacA11y', bigMacCount)}`
      : baseTooltip;
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
    if (key === 'monthlySalary') {
      state.settings = Core.updateMonthlySalary(state.settings, value);
    } else {
      state.settings[key] = value;
    }
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

  if (!offlineMode) {
    $('updatePromptButton').addEventListener('click', () => {
      if (!bridge) return;
      if (['available', 'downloaded'].includes(updateStatus.state)) {
        bridge.installUpdate();
      }
    });

    $('checkUpdatesToggle').addEventListener('change', event => {
      state.checkForUpdates = event.target.checked;
      if (!state.checkForUpdates) {
        state.autoUpdate = false;
      }
      saveState();
      render();
    });

    $('autoUpdateToggle').addEventListener('change', event => {
      state.autoUpdate = event.target.checked;
      if (state.autoUpdate) {
        state.checkForUpdates = true;
      }
      saveState();
      render();
    });

    $('updateAction').addEventListener('click', () => {
      if (!bridge) return;
      if (['available', 'downloaded'].includes(updateStatus.state)) {
        bridge.installUpdate();
      } else {
        bridge.checkForUpdates();
      }
    });
  }

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
  $('bigmacToggle').addEventListener('change', event => {
    state.bigMacCounter = event.target.checked;
    lastBigMacCount = null;
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
    if (!offlineMode && !updatePreviewMode) {
      bridge.onUpdateStatus(status => {
        if (status && typeof status === 'object') {
          updateStatus = status;
          renderUpdatePrompt();
          if (currentView === 'settings') renderSettings();
        }
      });
      bridge.getUpdateStatus().then(status => {
        if (status && typeof status === 'object') {
          updateStatus = status;
          renderUpdatePrompt();
          if (currentView === 'settings') renderSettings();
        }
      }).catch(() => {});
    }
  }
}

async function init() {
  let loaded = null;
  if (bridge) {
    try { loaded = await bridge.getState(); } catch {}
  }
  offlineMode = Boolean(loaded && loaded.offline);
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
  updatePreviewMode = params.get('updatePreview') === '1';
  if (updatePreviewMode) {
    state.checkForUpdates = true;
    state.autoUpdate = false;
    updateStatus = { state: 'available', version: '1.5.7', currentVersion: '1.5.6' };
  }
  if (params.get('bigmac') === '1') state.bigMacCounter = true;
  if (params.get('salaryPreview') === '1') {
    state.settings = Core.updateMonthlySalary(state.settings, 30000);
  }
  if (params.get('bigmacDrop') === '1') {
    const price = Core.bigMacPriceFor(state.currency).price;
    const perSecond = Core.rates(state.settings).perSecond;
    if (price > 0 && perSecond > 0) {
      const elapsed = price * 2 / perSecond - 1.15;
      if (elapsed > 0) {
        state.session = {
          phase: 'working',
          normalStartedAt: Date.now() - elapsed * 1000,
          normalEndedAt: null,
          overtimeStartedAt: null,
          overtimeEndedAt: null
        };
      }
    }
  }
  const bigmacTarget = Number(params.get('bigmacCount'));
  if (Number.isFinite(bigmacTarget) && bigmacTarget > 0) {
    const price = Core.bigMacPriceFor(state.currency).price;
    const perSecond = Core.rates(state.settings).perSecond;
    if (price > 0 && perSecond > 0) {
      const elapsed = price * bigmacTarget / perSecond;
      state.session = {
        phase: 'working',
        normalStartedAt: Date.now() - elapsed * 1000,
        normalEndedAt: null,
        overtimeStartedAt: null,
        overtimeEndedAt: null
      };
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
