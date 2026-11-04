'use strict';

const { contextBridge, ipcRenderer } = require('electron');

function on(channel, callback) {
  const listener = (_event, payload) => callback(payload);
  ipcRenderer.on(channel, listener);
  return () => ipcRenderer.removeListener(channel, listener);
}

contextBridge.exposeInMainWorld('desktop', {
  platform: process.platform,
  getState: () => ipcRenderer.invoke('state:get'),
  saveState: state => ipcRenderer.invoke('state:save', state),
  setTheme: theme => ipcRenderer.invoke('theme:set', theme),
  confirm: options => ipcRenderer.invoke('dialog:confirm', options),
  hide: () => ipcRenderer.send('window:hide'),
  quit: () => ipcRenderer.send('window:quit'),
  updateTray: payload => ipcRenderer.send('tray:update', payload),
  onCommand: callback => on('command', callback),
  onThemeChanged: callback => on('theme:changed', callback)
});
