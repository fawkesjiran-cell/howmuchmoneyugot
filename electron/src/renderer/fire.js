'use strict';

/**
 * Renders the overtime amount as burning glyphs. The fire is clipped to the
 * text alpha, then a hot core and a dark rim are drawn on top. It deliberately
 * stays small and hand-drawn so the Electron port keeps the macOS character.
 */
(function () {
  class FireRenderer {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.mask = document.createElement('canvas');
      this.maskCtx = this.mask.getContext('2d');
      this.text = '';
      this.theme = 'light';
      this.width = 180;
      this.height = 46;
      this.raf = 0;
      this.running = false;
      this.reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      this.frame = this.frame.bind(this);
    }

    setAmount(text, theme) {
      const changed = text !== this.text || theme !== this.theme;
      if (!changed) return;
      this.text = text;
      this.theme = theme;
      this.layout();
      this.draw(4.6);
      if (this.running && !this.reduceMotion) this.startLoop();
    }

    layout() {
      const ctx = this.ctx;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.font = '600 46px Geist, sans-serif';
      if ('letterSpacing' in ctx) ctx.letterSpacing = '-1.4px';
      const measured = ctx.measureText(this.text || '0').width;
      this.scale = Math.min(1, 300 / Math.max(1, measured));
      this.width = Math.max(36, Math.min(300, Math.ceil(measured * this.scale) + 4));
      this.height = 46;
      const dpr = 2;
      this.dpr = dpr;
      this.canvas.width = this.width * dpr;
      this.canvas.height = this.height * dpr;
      this.canvas.style.width = `${this.width}px`;
      this.canvas.style.height = `${this.height}px`;
      this.mask.width = this.canvas.width;
      this.mask.height = this.canvas.height;
    }

    start() {
      if (this.running) return;
      this.running = true;
      if (this.reduceMotion) {
        this.draw(4.6);
        return;
      }
      this.startLoop();
    }

    stop() {
      this.running = false;
      if (this.raf) cancelAnimationFrame(this.raf);
      this.raf = 0;
      const ctx = this.ctx;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    }

    startLoop() {
      if (this.raf) cancelAnimationFrame(this.raf);
      this.raf = requestAnimationFrame(this.frame);
    }

    frame(now) {
      if (!this.running) return;
      this.draw(now / 1000);
      this.raf = requestAnimationFrame(this.frame);
    }

    buildMask() {
      const mctx = this.maskCtx;
      mctx.setTransform(1, 0, 0, 1, 0, 0);
      mctx.clearRect(0, 0, this.mask.width, this.mask.height);
      mctx.scale(this.dpr * this.scale, this.dpr * this.scale);
      mctx.textAlign = 'left';
      mctx.textBaseline = 'alphabetic';
      mctx.fillStyle = '#FFFFFF';
      mctx.font = '600 46px Geist, sans-serif';
      if ('letterSpacing' in mctx) mctx.letterSpacing = '-1.4px';
      mctx.fillText(this.text, 0, 38);
    }

    draw(t) {
      const ctx = this.ctx;
      const W = this.width;
      const H = this.height;
      ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      ctx.clearRect(0, 0, W, H);
      this.buildMask();

      const palette = this.theme === 'dark'
        ? {
            base: ['#2B0710', '#6B0D1C', '#C21E36', '#FFE76F', '#8A5A00'],
            core: ['#FFFFF8', '#FFE76F', '#FFC83D', '#E72D48', '#8F1024'],
            rim: 'rgba(20, 6, 10, .55)',
            streak: ['rgba(255, 231, 111, .8)', 'rgba(231, 45, 72, .55)'],
            shape: 'source-over'
          }
        : {
            base: ['#3A0710', '#6B0D1C', '#C21E36', '#FFE76F', '#8A5A00'],
            core: ['#FFFFF8', '#FFE76F', '#FFC83D', '#E72D48', '#8F1024'],
            rim: 'rgba(43, 11, 18, .9)',
            streak: ['rgba(255, 231, 111, .7)', 'rgba(231, 45, 72, .45)'],
            shape: 'source-over'
          };

      const base = ctx.createLinearGradient(0, 3, 0, H);
      base.addColorStop(0, palette.base[0]);
      base.addColorStop(0.28, palette.base[1]);
      base.addColorStop(0.56, palette.base[2]);
      base.addColorStop(0.84, palette.base[3]);
      base.addColorStop(1, palette.base[4]);
      ctx.globalCompositeOperation = 'source-over';
      ctx.globalAlpha = 1;
      ctx.fillStyle = base;
      ctx.fillRect(0, 0, W, H);

      ctx.globalCompositeOperation = 'lighter';
      const rand = (i, salt) => {
        const value = Math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
        return value - Math.floor(value);
      };

      const streak = (i, minW, maxW, alpha, salt) => {
        const speed = 0.36 + rand(i, salt + 1.1) * 0.5;
        const progress = (rand(i, salt + 2.3) + t * speed) % 1;
        const x = rand(i, salt + 3.7) * W;
        const length = 8 + rand(i, salt + 4.9) * 22;
        const width = minW + rand(i, salt + 5.5) * (maxW - minW);
        const y = H - progress * (H + length);
        const sway = Math.sin(t * 1.2 + i * 2.13) * 2.2;
        const gradient = ctx.createLinearGradient(0, y + length, 0, y);
        gradient.addColorStop(0, 'rgba(255, 231, 111, 0)');
        gradient.addColorStop(0.42, palette.streak[1]);
        gradient.addColorStop(0.78, palette.streak[0]);
        gradient.addColorStop(1, 'rgba(255, 250, 220, .9)');
        ctx.globalAlpha = alpha * (0.7 + rand(i, salt + 6.1) * 0.3);
        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.moveTo(x - width / 2, y + length);
        ctx.quadraticCurveTo(x - width + sway, y + length / 2, x + sway, y);
        ctx.quadraticCurveTo(x + width + sway, y + length / 2, x + width / 2, y + length);
        ctx.closePath();
        ctx.fill();
      };

      for (let i = 0; i < 18; i += 1) streak(i, 4, 9, 0.55, 1.7);
      for (let i = 18; i < 48; i += 1) streak(i, 1, 3, 0.55, 5.3);

      for (let i = 0; i < 22; i += 1) {
        const speed = 0.3 + rand(i, 13.1) * 0.5;
        const progress = (rand(i, 14.3) + t * speed) % 1;
        const x = rand(i, 15.7) * W + Math.sin(t * 1.7 + i) * 2;
        const y = H - progress * (H + 6);
        const radius = 0.45 + rand(i, 16.9) * 0.9;
        ctx.globalAlpha = 0.3 + rand(i, 17.3) * 0.45;
        ctx.fillStyle = '#FFF6D0';
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, Math.PI * 2);
        ctx.fill();
      }

      ctx.globalCompositeOperation = 'destination-in';
      ctx.globalAlpha = 1;
      ctx.drawImage(this.mask, 0, 0, W, H);

      ctx.globalCompositeOperation = 'source-atop';
      const core = ctx.createLinearGradient(0, 3, 0, H);
      core.addColorStop(0, palette.core[0]);
      core.addColorStop(0.3, palette.core[1]);
      core.addColorStop(0.58, palette.core[2]);
      core.addColorStop(0.86, palette.core[3]);
      core.addColorStop(1, palette.core[4]);
      ctx.globalAlpha = 0.25;
      ctx.fillStyle = core;
      ctx.fillRect(0, 0, W, H);

      ctx.globalCompositeOperation = 'source-over';
      ctx.globalAlpha = 1;
      ctx.scale(this.scale, this.scale);
      ctx.textAlign = 'left';
      ctx.textBaseline = 'alphabetic';
      ctx.font = '600 46px Geist, sans-serif';
      if ('letterSpacing' in ctx) ctx.letterSpacing = '-1.4px';
      ctx.lineJoin = 'round';
      ctx.lineWidth = this.theme === 'dark' ? 0.45 : 0.6;
      ctx.strokeStyle = palette.rim;
      ctx.strokeText(this.text, 0, 38);
    }
  }

  window.FireRenderer = FireRenderer;
})();
