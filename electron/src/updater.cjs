'use strict';

const { autoUpdater } = require('electron-updater');

const CHECK_INTERVAL_MS = 6 * 60 * 60 * 1000;
const START_DELAY_MS = 1400;

/**
 * Wraps electron-updater for the tray app. The renderer owns the two opt-in
 * preferences; this module owns scheduling, status and the actual update flow.
 *
 * electron-updater works only in a packaged app. Development builds report
 * `unavailable` instead of throwing, so the settings page stays truthful.
 */
function createUpdater({ app, getWindow }) {
  let status = {
    state: 'disabled',
    currentVersion: app.getVersion()
  };
  let checkEnabled = false;
  let autoUpdateEnabled = false;
  let pendingManualInstall = false;
  let checking = false;
  let lastCheckAt = null;
  let interval = null;
  let kickoff = null;

  autoUpdater.autoDownload = false;
  autoUpdater.autoInstallOnAppQuit = false;
  autoUpdater.allowPrerelease = false;

  function send() {
    const window = getWindow();
    if (!window || window.isDestroyed()) return;
    window.webContents.send('update:status', status);
  }

  function setStatus(next) {
    status = {
      ...next,
      currentVersion: app.getVersion()
    };
    send();
  }

  function handleError(error) {
    checking = false;
    pendingManualInstall = false;
    const message = String(error && error.message ? error.message : error || '');
    console.error('[updater]', message);
    setStatus({
      state: 'error',
      message: message.slice(0, 240)
    });
  }

  function isBusy() {
    return ['checking', 'downloading', 'installing'].includes(status.state);
  }

  function check() {
    if (!app.isPackaged) {
      setStatus({ state: 'unavailable' });
      return status;
    }
    if (isBusy()) return status;

    checking = true;
    setStatus({ state: 'checking' });
    autoUpdater.checkForUpdates().catch(handleError);
    return status;
  }

  function download({ manual = true } = {}) {
    if (!['available', 'downloaded'].includes(status.state)) {
      return status;
    }
    if (status.state === 'downloaded') {
      return installDownloaded();
    }

    if (manual) pendingManualInstall = true;
    setStatus({
      state: 'downloading',
      version: status.version,
      percent: 0
    });
    autoUpdater.downloadUpdate().catch(handleError);
    return status;
  }

  function installDownloaded() {
    if (status.state !== 'downloaded') return status;
    setStatus({
      state: 'installing',
      version: status.version
    });
    setImmediate(() => {
      try {
        autoUpdater.quitAndInstall(false, true);
      } catch (error) {
        handleError(error);
      }
    });
    return status;
  }

  function install() {
    if (status.state === 'downloaded') return installDownloaded();
    if (status.state === 'available') return download();
    return check();
  }

  function clearTimers() {
    clearTimeout(kickoff);
    kickoff = null;
    clearInterval(interval);
    interval = null;
  }

  function scheduleKickoff() {
    clearTimeout(kickoff);
    kickoff = setTimeout(() => {
      kickoff = null;
      if (!checkEnabled) return;

      if (autoUpdateEnabled) {
        if (status.state === 'available') {
          download({ manual: false });
          return;
        }
        if (status.state === 'downloaded') {
          installDownloaded();
          return;
        }
      }

      if (['up-to-date', 'available', 'downloaded'].includes(status.state)
          && lastCheckAt != null
          && Date.now() - lastCheckAt < 10 * 60 * 1000) {
        return;
      }
      check();
    }, START_DELAY_MS);
  }

  function setPreferences(nextCheck, nextAuto, { initial = false } = {}) {
    const previousCheck = checkEnabled;
    const auto = Boolean(nextAuto);
    const checkNext = Boolean(nextCheck) || auto;
    checkEnabled = checkNext;
    autoUpdateEnabled = auto;

    if (!checkEnabled) {
      clearTimers();
      if (!isBusy()) setStatus({ state: 'disabled' });
      return;
    }

    if (!interval) {
      interval = setInterval(() => {
        if (checkEnabled) check();
      }, CHECK_INTERVAL_MS);
    }

    if (initial || !previousCheck) {
      if (status.state === 'disabled') setStatus({ state: 'idle' });
      scheduleKickoff();
      return;
    }

    if (autoUpdateEnabled && status.state === 'available') {
      download({ manual: false });
    } else if (autoUpdateEnabled && status.state === 'downloaded') {
      installDownloaded();
    }
  }

  autoUpdater.on('checking-for-update', () => {
    checking = true;
    setStatus({ state: 'checking' });
  });

  autoUpdater.on('update-available', info => {
    checking = false;
    lastCheckAt = Date.now();
    pendingManualInstall = false;
    setStatus({
      state: 'available',
      version: info && info.version ? info.version : undefined
    });
    if (autoUpdateEnabled) {
      download({ manual: false });
    }
  });

  autoUpdater.on('update-not-available', info => {
    checking = false;
    lastCheckAt = Date.now();
    pendingManualInstall = false;
    setStatus({
      state: 'up-to-date',
      version: info && info.version ? info.version : app.getVersion()
    });
  });

  autoUpdater.on('download-progress', progress => {
    setStatus({
      state: 'downloading',
      version: status.version,
      percent: progress && Number.isFinite(progress.percent)
        ? Math.max(0, Math.min(100, Math.round(progress.percent)))
        : undefined
    });
  });

  autoUpdater.on('update-downloaded', info => {
    checking = false;
    pendingManualInstall = pendingManualInstall || autoUpdateEnabled;
    setStatus({
      state: 'downloaded',
      version: info && info.version ? info.version : status.version
    });
    if (autoUpdateEnabled || pendingManualInstall) {
      installDownloaded();
    }
  });

  autoUpdater.on('error', handleError);

  return {
    check,
    install,
    getStatus: () => status,
    setPreferences
  };
}

module.exports = { createUpdater };
