(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('./core.js'));
  } else {
    root.Format = factory(root.Core);
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function (Core) {
  'use strict';
  const { CURRENCIES, LANGUAGES } = Core;


  function localeFor(language) {
    return (LANGUAGES[language] || LANGUAGES.en).locale;
  }

  function safe(value) {
    return Number.isFinite(Number(value)) ? Math.max(0, Number(value)) : 0;
  }

  function amount(value, language = 'en', options = {}) {
    const { grouped = true, minimumFractionDigits = 2, maximumFractionDigits = 2 } = options;
    return new Intl.NumberFormat(localeFor(language), {
      useGrouping: grouped,
      minimumFractionDigits,
      maximumFractionDigits
    }).format(safe(value));
  }

  function preciseAmount(value, language = 'en') {
    return amount(value, language, { maximumFractionDigits: 4, minimumFractionDigits: 4 });
  }

  function rate(value, decimals = 2) {
    return safe(value).toFixed(Math.max(0, Math.min(6, decimals)));
  }

  function count(value, language = 'en') {
    return new Intl.NumberFormat(localeFor(language), {
      useGrouping: true,
      maximumFractionDigits: 0
    }).format(safe(value));
  }

  function duration(seconds, paddedHours = true) {
    const total = Math.max(0, Math.floor(seconds));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const secs = total % 60;
    if (paddedHours) {
      return [hours, minutes, secs].map(v => String(v).padStart(2, '0')).join(':');
    }
    if (hours > 0) return `${hours}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    return `${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  }

  function clock(ms) {
    if (ms == null || !Number.isFinite(Number(ms))) return '--:--';
    const d = new Date(Number(ms));
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  }

  function money(value, currency = 'cny', language = 'en', options = {}) {
    const unit = CURRENCIES[currency] || CURRENCIES.cny;
    return unit.symbol + amount(value, language, options);
  }

  function currencyLabel(currency, language) {
    const unit = CURRENCIES[currency] || CURRENCIES.cny;
    return `${language === 'zh-Hans' ? unit.zh : unit.en} · ${unit.code}`;
  }

  return { localeFor, amount, preciseAmount, rate, count, duration, clock, money, currencyLabel };
});
