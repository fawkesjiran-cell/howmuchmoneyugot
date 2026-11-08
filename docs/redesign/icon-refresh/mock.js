/* Static snapshot of the Electron renderer for the icon comparison doc.
   It uses the real styles.css and markup, but no app JS/preload. */
(() => {
  const q = new URLSearchParams(location.search);
  const screen = q.get('screen') || 'main';
  const theme = q.get('theme') || 'light';
  const lang = q.get('lang') || (theme === 'dark' ? 'zh' : 'en');
  const zh = lang === 'zh';
  const root = document.documentElement;
  root.dataset.theme = theme;
  root.lang = zh ? 'zh-Hans' : 'en';

  const T = zh ? {
    thisSession: '本次', phaseWorking: '正常计薪中', allTime: '总计',
    dailyTarget: '日薪目标', perSecond: '每秒', perMinute: '每分', perHour: '每小时',
    clockIn: '上班', clockOut: '下班', startOvertime: '开始加班', endOvertime: '收工',
    in: '上班', out: '下班', ot: '加班', done: '收工',
    settingsTitle: '设置', back: '返回', doneAction: '完成', preferences: '偏好',
    language: '语言', currency: '货币单位', bigMacTitle: '你挣了几个巨无霸？',
    pay: '薪资', savedAsYouType: '输入即保存', monthlySalary: '普通月薪',
    workdays: '每月工作日', hours: '每日工时', overtimeRate: '加班时薪',
    rates: '费率', updates: '更新', updateCheckAuto: '自动检查更新',
    updateAutoInstall: '自动下载并安装', updateStatusDisabled: '自动检查未开启',
    updateCheckAction: '检查更新', data: '数据', resetEverything: '完全重置',
    resetCaption: '当前总计 %@，清空后无法恢复', clear: '清空',
    perMonth: '月', days: '天', hoursUnit: '小时', perHourUnit: '时'
  } : {
    thisSession: 'This session', phaseWorking: 'Earning regular pay', allTime: 'All time',
    dailyTarget: 'Daily target', perSecond: 'Per second', perMinute: 'Per minute', perHour: 'Per hour',
    clockIn: 'Clock in', clockOut: 'Clock out', startOvertime: 'Start overtime', endOvertime: 'Finish',
    in: 'In', out: 'Out', ot: 'OT', done: 'Done',
    settingsTitle: 'Settings', back: 'Back', doneAction: 'Done', preferences: 'Preferences',
    language: 'Language', currency: 'Currency', bigMacTitle: 'How many Big Macs u got?',
    pay: 'Pay', savedAsYouType: 'Saved as you type', monthlySalary: 'Monthly salary',
    workdays: 'Workdays per month', hours: 'Hours per day', overtimeRate: 'Overtime rate',
    rates: 'Rates', updates: 'Updates', updateCheckAuto: 'Check for updates automatically',
    updateAutoInstall: 'Download and install automatically', updateStatusDisabled: 'Automatic checks are off',
    updateCheckAction: 'Check for updates', data: 'Data', resetEverything: 'Reset everything',
    resetCaption: 'Current total %@. This cannot be undone.', clear: 'Clear',
    perMonth: 'mo', days: 'days', hoursUnit: 'hours', perHourUnit: 'hr'
  };

  const set = (id, text) => {
    const el = document.getElementById(id);
    if (el) el.textContent = text;
  };
  const setValue = (id, value) => {
    const el = document.getElementById(id);
    if (el) el.value = value;
  };
  const addClass = (id, cls) => {
    const el = document.getElementById(id);
    if (el) el.classList.add(cls);
  };

  // Shared header
  set('thisSessionLabel', T.thisSession);
  set('phaseText', T.phaseWorking);
  set('normalAmount', '400.89');
  set('currencySymbol', '¥');
  set('sessionTime', '03:12:25');
  set('allTime', `${T.allTime} ¥1,681.29`);
  set('targetLabel', `${T.dailyTarget} · ¥1,000.00`);
  set('targetPercent', '40%');
  const fill = document.getElementById('targetFill');
  if (fill) fill.style.width = '40%';
  set('rateSecLabel', T.perSecond);
  set('rateMinLabel', T.perMinute);
  set('rateHourLabel', T.perHour);
  set('rateSec', '0.0347');
  set('rateMin', '2.083');
  set('rateHour', '125.00');
  set('actionClockInLabel', T.clockIn);
  set('actionClockOutLabel', T.clockOut);
  set('actionOvertimeLabel', T.startOvertime);
  set('actionFinishLabel', T.endOvertime);
  set('railInLabel', T.in);
  set('railOutLabel', T.out);
  set('railOTLabel', T.ot);
  set('railDoneLabel', T.done);
  set('railInTime', '08:40');
  set('railOutTime', '--:--');
  set('railOTTime', '--:--');
  set('railDoneTime', '--:--');

  const themeIcon = document.getElementById('themeIcon');
  if (themeIcon) themeIcon.setAttribute('href', theme === 'dark' ? '#i-moon' : '#i-sun');

  const clockIn = document.getElementById('actionClockIn');
  if (clockIn) clockIn.disabled = true;
  addClass('actionClockOut', 'solid');
  addClass('actionOvertime', 'hint');
  const finish = document.getElementById('actionFinish');
  if (finish) finish.disabled = true;

  addClass('railIn', 'active');
  for (const id of ['railOut', 'railOT', 'railDone']) addClass(id, 'future');

  // Settings
  set('settingsTitle', T.settingsTitle);
  set('doneButton', T.doneAction);
  set('prefsLabel', T.preferences);
  set('languageLabel', T.language);
  set('currencyLabel', T.currency);
  set('bigmacTitle', T.bigMacTitle);
  set('payLabel', T.pay);
  set('savedHint', T.savedAsYouType);
  set('salaryLabel', T.monthlySalary);
  set('workdaysLabel', T.workdays);
  set('hoursLabel', T.hours);
  set('overtimeLabel', T.overtimeRate);
  set('ratesLabel', T.rates);
  set('updatesLabel', T.updates);
  set('checkUpdatesTitle', T.updateCheckAuto);
  set('autoUpdateTitle', T.updateAutoInstall);
  set('updateStatus', T.updateStatusDisabled);
  set('updateAction', T.updateCheckAction);
  set('dataLabel', T.data);
  set('resetTitle', T.resetEverything);
  set('resetCaption', T.resetCaption.replace('%@', '¥4,812.90'));
  set('clearButton', T.clear);

  set('salarySuffix', `CNY/${T.perMonth}`);
  set('workdaysSuffix', T.days);
  set('hoursSuffix', T.hoursUnit);
  set('overtimeSuffix', `CNY/${T.perHourUnit}`);
  setValue('salaryInput', '22,000');
  setValue('workdaysInput', '22');
  setValue('hoursInput', '8');
  setValue('overtimeInput', '187.5');
  set('setRateHour', '¥125.00');
  set('setRateMin', '¥2.083');
  set('setRateSec', '¥0.0347');
  set('updateVersion', 'v1.5.5');

  const languageSelect = document.getElementById('languageSelect');
  if (languageSelect) languageSelect.innerHTML = `<option selected>${zh ? '简体中文' : 'English'}</option>`;
  const currencySelect = document.getElementById('currencySelect');
  if (currencySelect) currencySelect.innerHTML = '<option selected>CNY ¥</option>';

  const main = document.getElementById('mainView');
  const settings = document.getElementById('settingsView');
  const showSettings = screen === 'settings';
  if (main) main.hidden = showSettings;
  if (settings) settings.hidden = !showSettings;

  if (showSettings) {
    const scroll = document.getElementById('settingsScroll');
    if (q.get('scroll') === '1') {
      const toBottom = () => { if (scroll) scroll.scrollTop = scroll.scrollHeight; };
      toBottom();
      requestAnimationFrame(() => { toBottom(); requestAnimationFrame(toBottom); });
    } else if (scroll) {
      scroll.scrollTop = 0;
    }
  }
})();
