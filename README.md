<p align="center">
  <img src="Resources/AppIcon.png" width="112" alt="How much money u got? 应用图标">
</p>

<h1 align="center">How much money u got?</h1>
<p align="center"><strong>一个安静、克制的实时工资计薪小工具。</strong></p>

<p align="center">
  <a href="https://github.com/fawkesjiran-cell/howmuchmoneyugot/releases">下载最新版本</a>
  ·
  <a href="README.en.md">English</a>
</p>

![主界面](docs/dashboard-light.png)

## 功能

- **实时收入** — 打卡后金额按秒实时累计，收入增长一眼可见。
- **正常与加班双费率** — 普通时薪和加班时薪分开设置，加班按你自己的倍率计算。
- **完整工作日** — 上班、下班、开始加班、收工，四个动作全部收在紧凑面板里。
- **数字里的火焰** — 加班金额的数字本身在燃烧，不遮挡卡片，也不会破坏可读性。
- **历史总计** — 完成的班次会沉淀到总计里，菜单栏金额不会回落。
- **安全重置** — 重置本次或清空全部都需要二次确认，不会误删记录。
- **菜单栏 / 系统托盘** — 从菜单栏或托盘打开面板，随时看到累计收入。
- **双语界面** — English 与简体中文可即时切换。
- **八种货币** — CNY、USD、EUR、GBP、JPY、HKD、KRW、SGD；仅切换显示符号。
- **你挣了几个巨无霸？** — 可选开启，按所选货币的 Big Mac 指数价格，把本次收入变成散落在金额旁的汉堡（最多同时 200 个）；悬停查看数量。
- **亮色、暗色或跟随系统** — 一个紧凑按钮循环切换，并记住你的选择。
- **可靠恢复** — 计时基于真实时间戳，睡眠或重启后仍能正确累计。
- **可控的 GitHub 更新** — 更新版可在设置里开启自动检查与自动下载安装；只访问 GitHub Releases，不包含遥测。
- **本地优先** — 设置和收入记录只保存在你的电脑上；更新检查默认关闭，离线版完全不使用网络。

| 加班计薪 | 设置页 |
| --- | --- |
| ![加班计薪](docs/overtime-light.png) | ![设置页](docs/settings-light.png) |

## 选择版本

| 版本 | 平台 | 更新 | 网络 |
| --- | --- | --- | --- |
| **macOS Swift（更新版）** | macOS 13+ | 应用内检查 / 自动安装 | 只发送更新请求 |
| **macOS Swift（离线版）** | macOS 13+ | 无更新器 | 完全不使用网络 |
| **Windows Electron（更新版）** | Windows 10/11 | 应用内检查 / 自动安装 | 只发送更新请求 |
| **Windows Electron（离线版）** | Windows 10/11 | 无更新器 | 完全不使用网络 |

- 更新版只会在自动检查或手动检查时访问 GitHub Releases；不包含遥测、统计、广告或其他后台数据传输。
- 更新版检测到新版本后，主页左上角图标会变成更新按钮；设置页的更新项位于“彻底重置”上方。
- 离线版不包含更新器，并阻断 HTTP / HTTPS / WebSocket 请求；不会向外部发送或接收任何数据。
- 更新检查默认关闭；开启后才会访问网络。

## 支持平台

| 平台 | 版本 |
| --- | --- |
| macOS 13+ | 原生 Swift（更新版 / 离线版） |
| Windows 10/11 | Electron（更新版 / 离线版） |

四个版本都可以从
[Releases](https://github.com/fawkesjiran-cell/howmuchmoneyugot/releases) 下载。

macOS 更新版：`How-Much-Money-U-Got-<version>-macOS-Swift.zip`
macOS 离线版：`How-Much-Money-U-Got-<version>-macOS-Offline.zip`
Windows 更新版：`How-Much-Money-U-Got-Setup-<version>.exe`
Windows 离线版：`How-Much-Money-U-Got-Offline-Setup-<version>.exe`

> Windows 的自动更新由 Setup 安装版提供；portable exe 与 zip 更适合手动更新。

## 技术栈

- **原生 macOS** — Swift、SwiftUI、AppKit
- **Windows** — Electron、JavaScript、HTML/CSS
- **加班动画** — Swift 端使用 Vortex，Electron 端使用 Canvas

## 致谢

- 由 [fawkesjiran-cell](https://github.com/fawkesjiran-cell) 制作。
- **Geist** 字体由 [Vercel](https://github.com/vercel/geist-font) 提供，遵循 SIL Open Font License 1.1。
- **Vortex** 粒子系统由 [Paul Hudson](https://github.com/twostraws/Vortex) 制作，遵循 MIT License。
- **Reicon** 图标库由 [Dev Chauhan](https://github.com/dqev/reicon) 制作，遵循 MIT License。
- 应用图标为项目定制的图形作品。
- Windows 版本使用 [Electron](https://www.electronjs.org) 与 Chromium，相关许可证同样适用。

完整第三方许可证文本见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 许可证

[MIT](LICENSE) © 2026 fawkesjiran-cell
