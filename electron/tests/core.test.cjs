'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  defaultState,
  normalizeState,
  rates,
  snapshot,
  applyAction,
  totalEarned,
  canClockIn,
  canClockOut,
  canStartOvertime,
  canEndOvertime
} = require('../src/core.js');

const settings = { monthlySalary: 22000, workDaysPerMonth: 22, hoursPerDay: 8, overtimeHourlyRate: 187.5 };
const t0 = Date.UTC(2026, 10, 4, 1, 0, 0);

test('derives normal and overtime rates', () => {
  const r = rates(settings);
  assert.equal(r.hourly, 125);
  assert.equal(r.perMinute, 125 / 60);
  assert.equal(r.perSecond, 125 / 3600);
  assert.equal(r.overtimeMultiplier, 1.5);
  assert.equal(r.dailyPay, 1000);
});

test('snapshot earns normal time while working', () => {
  const state = defaultState();
  state.settings = settings;
  state.session = { phase: 'working', normalStartedAt: t0, normalEndedAt: null, overtimeStartedAt: null, overtimeEndedAt: null };
  const s = snapshot(state.settings, state.session, t0 + 3600_000);
  assert.equal(s.phase, 'working');
  assert.equal(s.normalSeconds, 3600);
  assert.equal(s.normalEarned, 125);
  assert.equal(s.total, 125);
  assert.equal(s.activeHourlyRate, 125);
});

test('overtime uses overtime rate and ends with finish', () => {
  const state = defaultState();
  state.settings = settings;
  state.session = { phase: 'clockedOut', normalStartedAt: t0, normalEndedAt: t0 + 3600_000, overtimeStartedAt: null, overtimeEndedAt: null };
  applyAction(state, 'startOvertime', t0 + 3600_000);
  assert.equal(state.session.phase, 'overtime');
  const s = snapshot(state.settings, state.session, t0 + 7200_000);
  assert.equal(s.overtimeSeconds, 3600);
  assert.equal(s.overtimeEarned, 187.5);
  assert.equal(s.activeHourlyRate, 187.5);
  applyAction(state, 'endOvertime', t0 + 7200_000);
  assert.equal(state.session.phase, 'finished');
  assert.equal(canEndOvertime(state.session), false);
});

test('clocking in after finishing archives the previous session', () => {
  const state = defaultState();
  state.settings = settings;
  state.session = {
    phase: 'finished',
    normalStartedAt: t0,
    normalEndedAt: t0 + 3600_000,
    overtimeStartedAt: t0 + 3600_000,
    overtimeEndedAt: t0 + 7200_000
  };
  applyAction(state, 'clockIn', t0 + 8000_000);
  assert.equal(state.ledger.completedSessions, 1);
  assert.equal(state.ledger.completedEarnings, 312.5);
  assert.equal(state.session.phase, 'working');
  assert.equal(state.session.normalStartedAt, t0 + 8000_000);
  assert.equal(totalEarned(state, t0 + 8000_000), 312.5);
});

test('invalid transitions are no-ops', () => {
  const state = defaultState();
  state.session = { phase: 'idle', normalStartedAt: null, normalEndedAt: null, overtimeStartedAt: null, overtimeEndedAt: null };
  applyAction(state, 'clockOut', t0);
  applyAction(state, 'endOvertime', t0);
  assert.equal(state.session.phase, 'idle');
  assert.equal(canClockIn(state.session), true);
  assert.equal(canClockOut(state.session), false);
  assert.equal(canStartOvertime(state.session), false);
});

test('normalizes malformed persisted state', () => {
  const s = normalizeState({
    settings: { monthlySalary: -1, workDaysPerMonth: 'x', hoursPerDay: null, overtimeHourlyRate: Infinity },
    session: { phase: 'nonsense', normalStartedAt: 'bad' },
    ledger: { completedEarnings: -5, completedSessions: 2.9 },
    language: 'fr',
    currency: 'xxx',
    theme: 'pink'
  });
  assert.equal(s.settings.monthlySalary, 0);
  assert.equal(s.settings.workDaysPerMonth, 0);
  assert.equal(s.settings.hoursPerDay, 8);
  assert.equal(s.settings.overtimeHourlyRate, 0);
  assert.equal(s.session.phase, 'idle');
  assert.equal(s.session.normalStartedAt, null);
  assert.equal(s.ledger.completedEarnings, 0);
  assert.equal(s.ledger.completedSessions, 2);
  assert.equal(s.language, 'en');
  assert.equal(s.currency, 'cny');
  assert.equal(s.theme, 'system');
});
