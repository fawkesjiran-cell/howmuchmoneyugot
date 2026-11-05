'use strict';

const {
  app,
  BrowserWindow,
  Menu,
  Tray,
  dialog,
  ipcMain,
  nativeImage,
  nativeTheme,
  screen,
  session
} = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { normalizeState, DEFAULT_SETTINGS, defaultState } = require('./core.js');
const { readState, writeState } = require('./store.cjs');
const { t } = require('./i18n.js');

const WIDTH = 392;
const HEIGHT = 320;
const ROOT = path.join(__dirname, '..');
const CAPTURE = process.argv.includes('--capture');
const UPDATE_PREVIEW = CAPTURE && process.argv.includes('--update-preview');
const CAPTURE_PATH = (() => {
  const index = process.argv.indexOf('--capture');
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : null;
})();
const argValue = name => {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
};

// The packaged offline variant ships an offline.marker resource and never
// loads electron-updater. The update-enabled variant may only reach GitHub.
const OFFLINE_BUILD = process.env.HOWMUCH_OFFLINE === '1'
  || fs.existsSync(path.join(process.resourcesPath, 'offline.marker'));
const UPDATE_HOSTS = new Set([
  'github.com',
  'www.github.com',
  'api.github.com',
  'objects.githubusercontent.com',
  'github-releases.githubusercontent.com',
  'release-assets.githubusercontent.com'
]);

// Keep Chromium's background services quiet in both variants. The renderer
// only ever loads a local file; the update-enabled build talks to GitHub via
// electron-updater and nothing else.
app.commandLine.appendSwitch('disable-background-networking');
app.commandLine.appendSwitch('disable-component-update');
app.commandLine.appendSwitch('disable-domain-reliability');
app.commandLine.appendSwitch('disable-client-side-phishing-detection');
app.commandLine.appendSwitch('disable-sync');
app.commandLine.appendSwitch('no-pings');
app.commandLine.appendSwitch('disable-breakpad');
app.commandLine.appendSwitch('disable-features', [
  'OptimizationHints',
  'MediaRouter',
  'Translate',
  'AutofillServerCommunication',
  'CertificateTransparencyComponentUpdater',
  'InterestFeedContentSuggestions'
].join(','));

function installNetworkPolicy() {
  session.defaultSession.setSpellCheckerEnabled(false);
  session.defaultSession.setPermissionRequestHandler((_contents, _permission, callback) => {
    callback(false);
  });
  session.defaultSession.webRequest.onBeforeRequest(
    { urls: ['http://*/*', 'https://*/*', 'ws://*/*', 'wss://*/*'] },
    (details, callback) => {
      if (OFFLINE_BUILD) {
        callback({ cancel: true });
        return;
      }
      let allowed = false;
      try {
        const url = new URL(details.url);
        allowed = url.protocol === 'https:' && UPDATE_HOSTS.has(url.hostname);
      } catch {
        allowed = false;
      }
      callback(allowed ? {} : { cancel: true });
    }
  );
}

let mainWindow = null;
let tray = null;
let state = defaultState();
let stateFile = null;
let quitting = false;
let updater = null;
let lastTrayTitle = '';
let lastTrayTooltip = '';
let blurTimer = null;
let dialogOpen = false;

// `app.setName` also backs the default userData directory. A literal '?' is
// illegal in Windows paths, and Chromium then aborts startup before any window
// or tray exists: the process exits with code 0 and prints nothing. Keep the
// display name, but give Windows a filesystem-safe user-data directory. macOS
// allows '?' and keeps its existing folder, so saved state is left untouched.
app.setName('How much money u got?');
if (process.platform === 'win32') {
  app.setPath('userData', path.join(app.getPath('appData'), 'how-much-money-u-got'));
}
app.setAppUserModelId('com.fawkesjiran.jinzhang');

const singleInstance = app.requestSingleInstanceLock();
if (!singleInstance) {
  app.quit();
} else {
  app.on('second-instance', () => showWindow());
}

function darkNow() {
  return nativeTheme.shouldUseDarkColors;
}

function background() {
  return darkNow() ? '#1C1416' : '#FFFFFF';
}

function trayAsset(name) {
  const packaged = path.join(process.resourcesPath, 'tray', name);
  return fs.existsSync(packaged) ? packaged : path.join(ROOT, 'build', name);
}

function createTray() {
  const iconName = process.platform === 'darwin' ? 'trayTemplate.png' : 'tray.png';
  let image = nativeImage.createFromPath(trayAsset(iconName));
  if (process.platform === 'darwin') image.setTemplateImage(true);
  tray = new Tray(image);
  tray.setToolTip('How much money u got?');
  tray.on('click', () => toggleWindow());
  tray.on('right-click', () => showTrayMenu());
  tray.setIgnoreDoubleClickEvents?.(true);
}

function showTrayMenu() {
  if (!tray) return;
  const language = state.language;
  const menu = Menu.buildFromTemplate([
    {
      label: language === 'zh-Hans' ? '显示计薪面板' : 'Show earnings panel',
      click: () => showWindow()
    },
    {
      label: language === 'zh-Hans' ? '重置本次' : 'Reset session',
      click: () => {
        showWindow();
        mainWindow?.webContents.send('command', 'reset-session');
      }
    },
    { type: 'separator' },
    {
      label: language === 'zh-Hans' ? '退出' : 'Quit',
      click: () => {
        quitting = true;
        app.quit();
      }
    }
  ]);
  tray.popUpContextMenu(menu);
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: WIDTH,
    height: HEIGHT,
    useContentSize: true,
    frame: false,
    resizable: false,
    maximizable: false,
    minimizable: false,
    fullscreenable: false,
    show: false,
    skipTaskbar: true,
    hasShadow: true,
    backgroundColor: background(),
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false
    }
  });

  mainWindow.setAlwaysOnTop(true, 'floating');
  mainWindow.setVisibleOnAllWorkspaces?.(true, { visibleOnFullScreen: true });
  mainWindow.setMenuBarVisibility(false);
  mainWindow.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  mainWindow.webContents.on('before-input-event', (event, input) => {
    if (input.key === 'Escape') {
      event.preventDefault();
      hideWindow();
    }
  });

  const params = new URLSearchParams();
  if (argValue('--screen')) params.set('screen', argValue('--screen'));
  if (argValue('--theme')) params.set('theme', argValue('--theme'));
  if (argValue('--demo')) params.set('demo', argValue('--demo'));
  if (argValue('--lang')) params.set('lang', argValue('--lang'));
  if (process.argv.includes('--bigmac')) params.set('bigmac', '1');
  if (process.argv.includes('--bigmac-drop')) {
    params.set('bigmac', '1');
    params.set('bigmacDrop', '1');
  }
  if (argValue('--bigmac-count')) {
    params.set('bigmac', '1');
    params.set('bigmacCount', argValue('--bigmac-count'));
  }
  if (process.argv.includes('--salary-preview')) params.set('salaryPreview', '1');
  if (UPDATE_PREVIEW) params.set('updatePreview', '1');
  if (process.argv.includes('--scroll')) params.set('scroll', '1');
  if (CAPTURE) params.set('capture', '1');
  const url = pathToFileURL(path.join(__dirname, 'renderer', 'index.html'));
  if ([...params.keys()].length) url.search = params.toString();
  mainWindow.loadURL(url.toString());

  mainWindow.on('blur', () => {
    if (process.platform !== 'win32') return;
    if (CAPTURE || quitting || dialogOpen || !mainWindow || mainWindow.webContents.isDevToolsOpened()) return;
    clearTimeout(blurTimer);
    blurTimer = setTimeout(() => {
      if (mainWindow && !mainWindow.isDestroyed() && !mainWindow.isFocused()) hideWindow();
    }, 220);
  });

  mainWindow.on('close', event => {
    if (!quitting) {
      event.preventDefault();
      hideWindow();
    }
  });

  mainWindow.webContents.on('did-finish-load', () => {
    if (CAPTURE) {
      showWindow();
      const delayIndex = process.argv.indexOf('--capture-delay-ms');
      const delayValue = delayIndex >= 0 ? Number(process.argv[delayIndex + 1]) : NaN;
      const captureDelay = Number.isFinite(delayValue) && delayValue > 0 ? delayValue : 1600;
      setTimeout(async () => {
        try {
          const image = await mainWindow.webContents.capturePage();
          fs.mkdirSync(path.dirname(CAPTURE_PATH), { recursive: true });
          fs.writeFileSync(CAPTURE_PATH, image.toPNG());
        } catch (error) {
          console.error('Capture failed:', error);
          process.exitCode = 1;
        }
        quitting = true;
        app.quit();
      }, captureDelay);
    }
  });
}

function positionWindow() {
  if (!mainWindow || !tray) return;
  const trayBounds = tray.getBounds();
  const display = screen.getDisplayMatching(trayBounds);
  const area = display.workArea;
  const [width, height] = mainWindow.getSize();
  let x = Math.round(trayBounds.x + trayBounds.width / 2 - width / 2);
  x = Math.max(area.x + 8, Math.min(x, area.x + area.width - width - 8));
  const below = trayBounds.y < area.y + area.height / 2;
  let y = below
    ? Math.round(trayBounds.y + trayBounds.height + 6)
    : Math.round(trayBounds.y - height - 6);
  y = Math.max(area.y + 8, Math.min(y, area.y + area.height - height - 8));
  mainWindow.setPosition(x, y, false);
}

function showWindow() {
  if (!mainWindow) return;
  positionWindow();
  mainWindow.setAlwaysOnTop(true, 'floating');
  mainWindow.show();
  mainWindow.focus();
}

function hideWindow() {
  if (!mainWindow) return;
  mainWindow.hide();
  mainWindow.setAlwaysOnTop(false);
}

function toggleWindow() {
  if (!mainWindow) return;
  if (mainWindow.isVisible()) hideWindow();
  else showWindow();
}

function applyThemeSource(theme) {
  nativeTheme.themeSource = ['light', 'dark'].includes(theme) ? theme : 'system';
  mainWindow?.setBackgroundColor(background());
}

function save() {
  if (!stateFile || CAPTURE) return state;
  state = writeState(stateFile, state);
  return state;
}

function updateTray(payload = {}) {
  if (!tray) return;
  const title = String(payload.title || '');
  const tooltip = String(payload.tooltip || 'How much money u got?');
  if (process.platform === 'darwin' && title !== lastTrayTitle) {
    tray.setTitle(title);
    lastTrayTitle = title;
  }
  if (tooltip !== lastTrayTooltip) {
    tray.setToolTip(tooltip);
    lastTrayTooltip = tooltip;
  }
}

function installMenu() {
  if (process.platform !== 'darwin') return;
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    {
      label: app.name,
      submenu: [
        { role: 'about' },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideOthers' },
        { role: 'unhide' },
        { type: 'separator' },
        {
          label: t(state.language, 'settingsTitle'),
          accelerator: 'Command+,',
          click: () => {
            showWindow();
            mainWindow?.webContents.send('command', 'open-settings');
          }
        },
        { type: 'separator' },
        { role: 'quit' }
      ]
    },
    { role: 'editMenu' }
  ]));
}

async function bootstrap() {
  if (CAPTURE && !CAPTURE_PATH) {
    console.error('--capture requires a path');
    app.quit();
    return;
  }
  if (process.platform === 'darwin') app.dock?.hide();
  stateFile = path.join(app.getPath('userData'), 'state.json');
  const exists = fs.existsSync(stateFile);
  state = exists ? readState(stateFile) : defaultState();
  if (!exists) {
    state.language = app.getLocale().toLowerCase().startsWith('zh') ? 'zh-Hans' : 'en';
    state.settings = { ...DEFAULT_SETTINGS };
  }
  state = normalizeState(state);
  if (argValue('--theme')) state.theme = argValue('--theme');
  if (argValue('--updates-preview') === '1') {
    state.checkForUpdates = true;
    state.autoUpdate = argValue('--updates-auto-preview') === '1';
    state = normalizeState(state);
  }
  if (argValue('--screen') === 'settings') {
    // The renderer chooses the route; no persistence is needed.
  }
  applyThemeSource(state.theme);
  installNetworkPolicy();
  createWindow();
  createTray();
  installMenu();

  if (!OFFLINE_BUILD && !UPDATE_PREVIEW) {
    const { createUpdater } = require('./updater.cjs');
    updater = createUpdater({ app, getWindow: () => mainWindow });
    updater.setPreferences(state.checkForUpdates, state.autoUpdate, { initial: true });
  }

  const shouldOpen = !state.hasLaunched || process.argv.includes('--show') || CAPTURE || Boolean(argValue('--screen'));
  if (shouldOpen) {
    mainWindow.once('ready-to-show', () => {
      showWindow();
      if (!CAPTURE) {
        state.hasLaunched = true;
        save();
      }
    });
  }

}

ipcMain.handle('state:get', () => ({ ...state, offline: OFFLINE_BUILD }));

ipcMain.handle('state:save', (_event, next) => {
  const previousCheck = state.checkForUpdates;
  const previousAuto = state.autoUpdate;
  state = normalizeState(next);
  save();
  installMenu();
  if (updater && (previousCheck !== state.checkForUpdates || previousAuto !== state.autoUpdate)) {
    updater.setPreferences(state.checkForUpdates, state.autoUpdate);
  }
  return state;
});

if (!OFFLINE_BUILD) {
  ipcMain.handle('update:status', () => {
    return updater ? updater.getStatus() : {
      state: 'disabled',
      currentVersion: app.getVersion()
    };
  });

  ipcMain.handle('update:check', () => {
    return updater ? updater.check() : null;
  });

  ipcMain.handle('update:install', () => {
    return updater ? updater.install() : null;
  });
}

ipcMain.handle('theme:set', (_event, theme) => {
  state.theme = ['system', 'light', 'dark'].includes(theme) ? theme : 'system';
  applyThemeSource(state.theme);
  save();
  return state.theme;
});

ipcMain.handle('dialog:confirm', async (_event, options = {}) => {
  if (!mainWindow) return false;
  dialogOpen = true;
  let result;
  try {
    result = await dialog.showMessageBox(mainWindow, {
    type: 'warning',
    title: String(options.title || ''),
    message: String(options.message || ''),
    detail: options.detail ? String(options.detail) : undefined,
    buttons: [String(options.cancelLabel || 'Cancel'), String(options.confirmLabel || 'OK')],
    defaultId: 1,
    cancelId: 0,
    noLink: true
    });
  } finally {
    dialogOpen = false;
  }
  return result.response === 1;
});

ipcMain.on('window:hide', hideWindow);
ipcMain.on('window:quit', () => {
  quitting = true;
  app.quit();
});
ipcMain.on('tray:update', (_event, payload) => updateTray(payload));

nativeTheme.on('updated', () => {
  mainWindow?.setBackgroundColor(background());
  mainWindow?.webContents.send('theme:changed', nativeTheme.shouldUseDarkColors ? 'dark' : 'light');
});

app.whenReady().then(bootstrap).catch(error => {
  console.error(error);
  app.quit();
});

app.on('window-all-closed', () => {
  // This is a tray app; closing the panel must not quit the process.
});

app.on('activate', () => showWindow());

app.on('before-quit', () => {
  quitting = true;
});
