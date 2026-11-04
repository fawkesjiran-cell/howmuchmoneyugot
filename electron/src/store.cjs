'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { normalizeState, defaultState } = require('./core.js');

function readState(filePath) {
  try {
    const raw = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    return normalizeState(raw);
  } catch {
    return defaultState();
  }
}

function writeState(filePath, state) {
  const normalized = normalizeState(state);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const temp = `${filePath}.tmp`;
  fs.writeFileSync(temp, JSON.stringify(normalized, null, 2));
  fs.renameSync(temp, filePath);
  return normalized;
}

module.exports = { readState, writeState };
