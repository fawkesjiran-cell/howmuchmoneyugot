# Pine Ledger — 主界面与设置页重设计

`How much money u got?` 的 light / dark 主题与 392 × 320 页面稿。

## 概念

一台**精密仪表**，不是 dashboard。余额是读数，session rail 是刻度；松绿代表已赚到的钱，余烬橙只代表加班，红色只用于破坏性操作。没有渐变文字、玻璃拟态、卡片投影或装饰性火焰。唯一例外是加班态：数字本身燃烧，火焰只存在于字形内部与紧贴字形的火舌里，不铺背景、不做火床。

## 文件

| 文件 | 内容 |
| --- | --- |
| `panel.html` | 可切换的主界面 / 设置页，light / dark，支持滚动态 |
| `theme.html` | Light + Dark token 板、字号与组件示例 |
| `shots/main-light.png` | 主界面 light，2× |
| `shots/main-dark.png` | 主界面 dark，2× |
| `shots/main-light-overtime.png` | 加班态 light，2×，数字着火 |
| `shots/main-dark-overtime.png` | 加班态 dark，2×，数字着火 |
| `shots/fire-light.gif` | 加班火数字动态细节（24 帧） |
| `shots/fire-dark.gif` | 加班火数字动态细节（dark，24 帧） |
| `shots/settings-light.png` | 设置页 light（首屏） |
| `shots/settings-dark.png` | 设置页 dark（首屏） |
| `shots/settings-light-scrolled.png` | 设置页 light（滚到底，Data 区） |
| `shots/settings-dark-scrolled.png` | 设置页 dark（滚到底，Data 区） |
| `shots/overview.png` | 四屏总览 |
| `shots/theme-light-dark.png` | 主题板 2× |

## 查看

```bash
cd /Users/jishu/Desktop/howmuchmoneyugot
python3 -m http.server 8765 --bind 127.0.0.1
```

- 主界面：`http://127.0.0.1:8765/docs/redesign/panel.html?screen=main&theme=light`
- 加班态：`?screen=main&theme=light&mode=overtime`（动态燃烧）
- 加班态静态帧：追加 `&freeze=1`（截图用，固定 4.6s 的火形）
- 设置页：`?screen=settings&theme=light`
- 设置页滚动态：`?screen=settings&theme=light&scroll=1`
- 去掉 stage、只看 392×320：加 `&bare=1`
- 2× 输出：加 `&zoom=2`，窗口设为 912×768

## Token

### Light

| Role | Hex | 用途 |
| --- | --- | --- |
| canvas | `#F3F6F4` | popover 背景 |
| surface | `#FFFFFF` | 卡片、输入框 |
| ink | `#0E1F18` | 主文字、余额 |
| muted | `#55685E` | 标签、次要值 |
| faint | `#5F746A` | 时间戳、辅助说明（≥ 4.5:1） |
| primary | `#146B4A` | 赚钱、主按钮、进度 |
| ember | `#A5480A` | 加班 |
| danger | `#B3261E` | 仅破坏性操作 |
| line | `#DCE5DF` | 1px 分隔线 |

### Dark

| Role | Hex | 用途 |
| --- | --- | --- |
| canvas | `#091310` | popover 背景 |
| surface | `#111E18` | 卡片、输入框 |
| ink | `#EAF2ED` | 主文字、余额 |
| muted | `#9FB3A7` | 标签、次要值 |
| faint | `#7C9185` | 时间戳、辅助说明 |
| primary | `#5BD6A0` | 赚钱、主按钮、进度 |
| ember | `#F0A868` | 加班 |
| danger | `#FF8177` | 仅破坏性操作 |
| line | `#263A30` | 1px 分隔线 |

字体：Geist 400 / 500 / 600；所有金额、时间使用 `tabular-nums`。中文回退到系统 PingFang SC。

## 版式

- 主界面：`12px` 上下内边距 + 36px header + 86px 余额 + 22px 目标 + 44px 费率 + 40px 操作 + 28px rail + 5 × 8px 间距 = **320px**，不滚动。
- 设置页：52px header + 可滚动内容；首屏露出 Pay 卡与 `Rates` 标签，底部 16px fade 提示继续滚动；滚到底显示 Rates + Data + Reset。
- 圆角：控件 8px，卡片 12px，panel 16px。卡片只有 1px 边框，无阴影。
- 操作行四个按钮中始终只有一个 filled primary：正常态是 `Clock out`，加班态是 `Finish`；`Start overtime` 在加班态禁用，避免两个暖色主操作。

## 演示数据

正常态：月薪 `7,480` / 22 天 / 8 小时 → 时薪 `42.50`；加班 `63.75`（1.5×）；日目标 `340.00`；session `05:26:53` → `¥231.54`；all-time `¥4,812.90`；目标进度 `68%`。

加班态：`09:02` 上班、`17:30` 下班、`17:31` 开始加班，当前 `19:01:53`；正常段 `8h28m` × `42.50` = `359.83`，加班段 `1h30m53s` × `63.75` = `96.56`，合计 `¥456.39`；all-time `¥5,037.75`；日目标 `134%`；费率为 `0.0177 / 1.063 / 63.75`。中英两套文案沿用 `Sources/HowMuchApp/Localization.swift`，mock 用英文。

## 加班火数字

- 只烧数字，不烧卡片：`340×46` canvas @2×，先画火，再用文字 alpha 掩膜裁切；没有火床、没有背景火。
- 火体：深余烬 `#5A1002` → `#A32605` → `#D94A08` → `#4A0C02`，叠加 20 条宽火舌 + 44 条细流 + 26 个火星；再加一层很轻的白金熔芯（12%）。
- 字形边缘：light 用 `0.6px` 深棕描边 `#2A0A04` 保住可读性；dark 只留 `0.45px` 低透明描边，让辉光定义边缘。
- 紧贴字形的 12 条火舌与 18 个余烬可以越出字形几像素，制造“数字在烧”的生命感；不向下方铺火。
- 动态：30fps 画布、3.8s 数字呼吸、2.4s 状态点脉冲；`prefers-reduced-motion` 与 `?freeze=1` 都退化为 4.6s 的静态火形。
- 可访问性：canvas 带 `role="img"` 和 `¥456.39` 的 `aria-label`；金额语义不依赖火焰。

## SwiftUI 落地

这套稿已经落进 `Sources/HowMuchApp/`，不是只停在 HTML：

- `Theme.swift`：Pine Ledger 的 light/dark token（canvas、surface、line、ink、muted、faint、primary、ember、danger），`AppBackground` 改为纯 canvas，卡片统一 1px hairline、无阴影。
- `DashboardView.swift`：36px header + 86px 余额 + 22px 目标 + 44px 费率 + 40px 操作 + 28px rail，固定 392×320；费率按 `4 / 3 / 2` 位小数显示，操作行始终只有一个 filled primary。主 header 按 mock 的嵌套 padding 使用 32px 总 inset（左右各 32），reset/gear 为 28px 圆形热区、13px 线性图标，不再贴到面板边缘。
- `SettingsView.swift`：52px header、可滚动 Preferences / Pay / Rates / Data；语言和货币用自绘的 31px 控件 + 原生菜单（避免嵌套 popover 把状态栏面板关掉），Pay 输入框保留原有 `PaySettings` 绑定与校验，重置仍走原来的二次确认。设置页首页 section 间距按 mock 的 4px margin 重新对齐。
- `AppFont.swift` + `Resources/Fonts/Geist[wght].ttf`：Geist 已真正打包并注册，正文/金额/标题都使用同一套 400/500/600 字重，中文回退系统 CJK；不是 SF Pro 近似。因 app bundle 名含 `?`，CoreText 直接按原路径注册会得到一个只有 7 个 glyph 的占位字体，所以注册前先复制到无特殊字符的临时路径。
- `OvertimeFlame.swift`：保留原有 Canvas + Vortex 火体，改成 **只烧数字**；货币符号保持实心 ember 并加很轻的暖光，避免 20px 的 `¥` 被火舌和描边糊成 `8`，金额仍能一眼读清。数字本身仍使用深余烬底、流动火舌、熔芯、light 深棕描边 / dark 低透明描边。
- `Localization.swift`：新增 Preferences/Pay/Rates/Data、短 rail 标签和“输入即保存”的中英文案。

实际 SwiftUI 渲染截图（784×640 = 2× 392×320）：

- `shots/app-main-light.png` / `shots/app-main-dark.png`
- `shots/app-main-overtime-light.png` / `shots/app-main-overtime-dark.png`
- `shots/app-settings-light.png` / `shots/app-settings-dark.png`
- `shots/app-settings-light-scroll.png` / `shots/app-settings-dark-scroll.png`
- `shots/app-main-overtime-zh.png` / `shots/app-settings-zh.png`

验证：`swift build`、`CoreChecks`、release 打包、打包后 app 的 `--capture-overtime` 均通过；上述截图全部由真实 `NSHostingView` 以 sRGB 渲染（不再带 Display P3 profile）并用 macOS Vision OCR 核对，主色与 HTML 稿的 `#146B4A / #F3F6F4` 逐像素一致。`×1.5`、`Start overtime`、中文短 rail、设置页滚到底的 Rates/Data 都能完整显示。

Stitch 仍是“主题已成、页面未出”；落地截图不是 Stitch screen。

## Stitch

- 项目：`https://stitch.withgoogle.com/projects/16079831687750854600`
- Light design system：`assets/4176454413293761069`
- Dark design system：`assets/9187921838419959946`

Stitch 的 `generate_screen_from_text` 共尝试 3 次（AGNOSTIC，`GEMINI_3_8_FLASH` / `GEMINI_3_5_FLASH_LITE`，带 light design system），每次都只返回 `sessionId`，`list_screens` 持续为空；更早的 20+ 分钟轮询、MOBILE/AGNOSTIC、独立测试项目也一样。因此本目录的 PNG 与 GIF **不是 Stitch 直接生成的 screen**，而是用同一套 Stitch token 在本地按 392×320 精确渲染的稿。Stitch 内目前是“主题已成、页面未出”，没有把本地图伪装成 Stitch 产物。

## 验证

- 8 张页面图：912×768（panel 784×640 = 2× 392×320），DOM 无横向溢出、无文字裁切；加班态 OCR 核对 `456.39 / 09:59:53 / 5,037.75 / 134% / 0.0177 / 1.063 / 63.75 / Finish` 与四段 rail。
- 火数字动态：24 帧 GIF，80ms/帧；live page 250ms 内约 52% 画布像素变化，确认不是静态贴图。
- Stitch screen 数量：0；这是当前唯一未完成的交付边界。
- 对比度：light ink 15.7 / muted 5.5 / faint 4.6 / primary 6.5；dark ink 16.6 / muted 8.5 / faint 5.1 / primary 9.5。
- macOS Vision OCR 逐屏核对全部标签；`¥` 会被 OCR 误读为 `·`，源文件与实际字形为 `¥`。
