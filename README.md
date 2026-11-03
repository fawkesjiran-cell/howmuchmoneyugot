# How much money u got?

一个常驻 macOS 菜单栏的实时工资计薪小工具。应用名固定为 **How much money u got?**，不随语言切换；界面支持简体中文 / English，以及多种货币单位显示。

<img src="Resources/AppIcon.png" width="96" alt="How much money u got? App 图标">

![首页](docs/dashboard-light.png)

## 功能

- **收入换算**：填写普通月薪、每月工作日、每日工时、加班时薪，自动换算成每秒 / 每分钟 / 每小时收入。
- **实时累计**：正常上班与加班分别累计，金额精确到分，费率随当前处于正常或加班状态自动切换。
- **记录不丢失**：下班或收工后再次上班，上一次收入会自动归入“总计”；本次从零重新累计，但总计和菜单栏金额不会回落。
- **完整打卡流程**：紧凑操作条中的上班、下班、加班、收工四个动作，覆盖一天的工作节奏。
- **菜单栏小组件**：右上角常驻显示持久化的累计总计，图标与符号跟随货币切换；左键打开面板，右键可快速重置本次或退出。
- **双语界面**：简体中文 / English 即时切换，面板、菜单栏提示、右键菜单、系统菜单与弹窗同步更新；应用名始终保持 **How much money u got?**。
- **可选货币单位**：人民币、美元、欧元、英镑、日元、港币、韩元、新加坡元；切换只改变显示符号，不换算已填写的金额。
- **状态自动恢复**：所有计时都基于真实时间戳，Mac 睡眠、退出应用后重新打开都会继续正确累计。
- **本机存储**：设置、语言、货币与计时记录只保存在本机 `UserDefaults`，不上传任何数据。
- **深浅色适配**：自动跟随系统外观。

| 中文 | English |
| --- | --- |
| ![中文首页](docs/dashboard-light.png) | ![English dashboard](docs/dashboard-en.png) |
| ![中文设置](docs/settings-light.png) | ![English settings](docs/settings-en.png) |

深色模式：

![深色](docs/dashboard-dark.png)

## 安装与运行

要求：macOS 13 或更高版本；只需安装 Xcode Command Line Tools，不依赖第三方库。

```bash
git clone https://github.com/fawkesjiran-cell/howmuchmoneyugot.git
cd howmuchmoneyugot
./Scripts/build_app.sh
open "dist/How much money u got?.app"
```

构建产物在 `dist/How much money u got?.app`。首次打开会自动弹出计薪面板；之后点击菜单栏右上角的金额小组件即可打开。

也可以直接用于开发调试：

```bash
swift run HowMuch
```

应用采用 ad-hoc 签名，未经过 Apple 公证。如果从网络下载后被 Gatekeeper 拦截，请在 Finder 中右键应用并选择“打开”。

## 使用

1. 点击面板右上角的齿轮，选择语言、货币单位，并填写月薪、每月工作日、每日工时和加班时薪。
2. 点击操作条中的 **上班**，本次金额开始实时累计；面板右下角和菜单栏同时显示累计总计。
3. 下班时点击 **下班**；如果需要加班，再点击 **加班**，加班时薪会立即生效。
4. 加班结束点击 **收工**，本次计薪完成并保留结果。
5. 再次点击 **上班** 会保留上一次收入并开启新的“本次”；第一段收入已经计入总计，菜单栏数字不会归零。右上角重置图标只清空本次，历史总计不受影响。

切换货币只会更新金额前的符号（例如 `¥` → `$`），不会自动换算数字。右击菜单栏图标可以直接打开面板、重置本次计薪或退出应用。

## 计算方式

```text
普通时薪 = 普通月薪 ÷ (每月工作日 × 每日工时)
每秒收入 = 时薪 ÷ 3600
每分钟收入 = 时薪 ÷ 60
每小时收入 = 时薪

本次累计 = 正常工时 × 普通每秒收入 + 加班工时 × 加班每秒收入
```

加班时薪独立于普通时薪保存。右击设置页中的加班时薪行，可按普通时薪的 1.5 倍填入。

计时金额由开始/结束时间戳推导，不依赖定时器累加，因此应用重启、电脑休眠或系统时间短暂卡顿都不会丢失时长。

## 项目结构

```text
Sources/
  HowMuchCore/    纯计算模型、状态机、收入快照
  HowMuchApp/     SwiftUI 界面、AppKit 菜单栏组件、双语本地化、持久化
Tests/
  CoreChecks/     无 XCTest 依赖的核心逻辑检查
Resources/        Info.plist、应用图标
Scripts/          图标生成、打包、核心检查
```

## 开发

```bash
# 构建调试版本
swift build

# 运行核心逻辑检查
./Scripts/check.sh

# 生成图标
python3 Scripts/make_icon.py   # 需要 Pillow

# 构建并签名 .app
./Scripts/build_app.sh
```

## 数据

- 设置项、语言、货币单位、本次计时状态与历史总计保存在本机 `UserDefaults`。
- 应用没有网络权限，也没有任何统计或上报代码。
- 重置本次计薪只清除当前“本次”金额，历史总计保留。

## License

[MIT](LICENSE) © 2026 fawkesjiran-cell
