import HowMuchCore

enum LKey: Hashable {
    // Brand & common
    case cancel
    case reset
    case done
    case back
    case settings
    case appearanceSystem
    case appearanceLight
    case appearanceDark
    case appearanceHelp
    case appearanceToast
    case language
    case languageHint
    case currency
    case bigMacCounterTitle
    case bigMacCounterHint
    case bigMacHoverCount
    case bigMacAccessibility
    case bigMacPriceHint

    // Dashboard
    case earnedThisSession
    case sessionCurrentLabel
    case totalLabel
    case dailyTarget
    case perSecond
    case perMinute
    case perHour
    case clockIn
    case clockOut
    case startOvertime
    case endOvertime
    case actionInShort
    case actionOutShort
    case actionOvertimeShort
    case actionDoneShort
    case timelineClockIn
    case timelineClockOut
    case timelineOvertime
    case timelineDone
    case timelineInShort
    case timelineOutShort
    case timelineOTShort
    case timelineDoneShort
    case phaseTitleIdle
    case phaseTitleWorking
    case phaseTitleClockedOut
    case phaseTitleOvertime
    case phaseTitleFinished
    case resetThisSession
    case resetConfirmTitle
    case resetConfirmMessage

    // Settings
    case settingsTitle
    case preferences
    case paySection
    case ratesSection
    case dataSection
    case updatesSection
    case autoCheckUpdates
    case autoCheckUpdatesHint
    case autoInstallUpdates
    case autoInstallUpdatesHint
    case checkForUpdates
    case installUpdate
    case updateRetry
    case updateStatusDisabled
    case updateStatusIdle
    case updateStatusChecking
    case updateStatusUpToDate
    case updateStatusAvailable
    case updateStatusDownloading
    case updateStatusPreparing
    case updateStatusInstalling
    case updateFailureNetwork
    case updateFailureMissingAsset
    case updateFailureChecksum
    case updateFailureUnsafe
    case updateFailurePackage
    case updateFailureInstall
    case updatePromptTitle
    case updatePromptHint
    case paySavedHint
    case monthlySalary
    case workdaysPerMonth
    case hoursPerDay
    case overtimeHourly
    case fillSuggestedRate
    case currencyDisplayOnlyNote
    case perMonthSuffix
    case perHourSuffix
    case daysSuffix
    case hoursSuffix
    case fullResetTitle
    case fullResetCaption
    case fullResetAction
    case fullResetConfirmTitle
    case fullResetConfirmMessage
    case fullResetConfirmAction

    // Status item & menus
    case statusAccessibilityLabel
    case statusAccessibilityValue
    case statusTooltip
    case openApp
    case quitApp
    case showPanel
    case aboutApp
    case editMenu
    case undo
    case redo
    case cut
    case copy
    case paste
    case selectAll
}

enum L10n {
    static func text(
        _ key: LKey,
        language: AppLanguage,
        arguments: [CVarArg] = []
    ) -> String {
        let table = language == .zhHans ? chinese : english
        let format = table[key] ?? keyString(key)
        guard !arguments.isEmpty else { return format }
        return String(format: format, arguments: arguments)
    }

    private static func keyString(_ key: LKey) -> String {
        String(describing: key)
    }

    private static let chinese: [LKey: String] = [
        .cancel: "取消",
        .reset: "重置",
        .done: "完成",
        .back: "返回",
        .settings: "设置",
        .appearanceSystem: "跟随系统",
        .appearanceLight: "亮色",
        .appearanceDark: "暗色",
        .appearanceHelp: "外观：%@ · 点击切换",
        .appearanceToast: "外观：%@",
        .language: "语言",
        .languageHint: "界面会立即切换",
        .currency: "货币单位",
        .bigMacCounterTitle: "你挣了几个巨无霸？",
        .bigMacCounterHint: "把本次收入按当前货币的 Big Mac 价格换成散落在金额旁的汉堡；悬停查看数量。",
        .bigMacHoverCount: "%d 个巨无霸",
        .bigMacAccessibility: "本次已赚可买 %d 个巨无霸",
        .bigMacPriceHint: "《经济学人》Big Mac 指数 · 2025.01 · %@ %@",

        .earnedThisSession: "本次已赚",
        .sessionCurrentLabel: "本次",
        .totalLabel: "总计",
        .dailyTarget: "日薪目标",
        .perSecond: "每秒",
        .perMinute: "每分",
        .perHour: "每小时",
        .clockIn: "打卡上班",
        .clockOut: "打卡下班",
        .startOvertime: "开始加班",
        .endOvertime: "结束加班",
        .actionInShort: "上班",
        .actionOutShort: "下班",
        .actionOvertimeShort: "加班",
        .actionDoneShort: "收工",
        .timelineClockIn: "上班",
        .timelineClockOut: "下班",
        .timelineOvertime: "加班",
        .timelineDone: "收工",
        .timelineInShort: "上班",
        .timelineOutShort: "下班",
        .timelineOTShort: "加班",
        .timelineDoneShort: "收工",
        .phaseTitleIdle: "待打卡",
        .phaseTitleWorking: "正常计薪中",
        .phaseTitleClockedOut: "已打卡下班",
        .phaseTitleOvertime: "加班计薪中",
        .phaseTitleFinished: "本次已完成",
        .resetThisSession: "重置本次",
        .resetConfirmTitle: "重置本次计薪？",
        .resetConfirmMessage: "本次的 %@ 将清零，历史总计会保留。",

        .settingsTitle: "设置",
        .preferences: "偏好",
        .paySection: "薪资",
        .ratesSection: "费率",
        .dataSection: "数据",
        .updatesSection: "更新",
        .autoCheckUpdates: "自动检查更新",
        .autoCheckUpdatesHint: "启动时以及每隔几小时在 GitHub Releases 检查新版本。",
        .autoInstallUpdates: "自动下载并安装",
        .autoInstallUpdatesHint: "发现新版本后自动校验、安装并重启；失败时保留当前版本。",
        .checkForUpdates: "检查更新",
        .installUpdate: "安装更新",
        .updateRetry: "重试",
        .updateStatusDisabled: "自动检查未开启",
        .updateStatusIdle: "尚未检查更新",
        .updateStatusChecking: "正在检查更新…",
        .updateStatusUpToDate: "已是最新版本",
        .updateStatusAvailable: "发现新版本 %@",
        .updateStatusDownloading: "正在下载 %@…",
        .updateStatusPreparing: "正在准备更新…",
        .updateStatusInstalling: "即将重启完成更新…",
        .updateFailureNetwork: "无法连接 GitHub，请稍后重试。",
        .updateFailureMissingAsset: "该版本没有可用的 macOS 安装包。",
        .updateFailureChecksum: "更新包校验失败，已取消安装。",
        .updateFailureUnsafe: "当前安装位置无法自动更新，请从 Releases 手动下载。",
        .updateFailurePackage: "更新包无效，已取消安装。",
        .updateFailureInstall: "自动安装失败，请从 Releases 手动下载。",
        .updatePromptTitle: "更新到 %@",
        .updatePromptHint: "发现新版本 %@，点击安装并重启。",
        .paySavedHint: "输入即保存",
        .monthlySalary: "普通月薪",
        .workdaysPerMonth: "每月工作日",
        .hoursPerDay: "每日工时",
        .overtimeHourly: "加班时薪",
        .fillSuggestedRate: "按 1.5× 填入 %@",
        .currencyDisplayOnlyNote: "切换货币只改变显示符号，不会换算已填写的金额。",
        .perMonthSuffix: "月",
        .perHourSuffix: "时",
        .daysSuffix: "天",
        .hoursSuffix: "小时",
        .fullResetTitle: "完全重置",
        .fullResetCaption: "当前总计 %@，清空后无法恢复",
        .fullResetAction: "清空",
        .fullResetConfirmTitle: "完全重置所有金额？",
        .fullResetConfirmMessage: "总计 %@（含本次 %@）将被永久清空，并停止当前计时。此操作无法撤销。",
        .fullResetConfirmAction: "完全重置",

        .statusAccessibilityLabel: "实时收入",
        .statusAccessibilityValue: "%@，%@",
        .statusTooltip: "%@ · %@ · %@",
        .openApp: "打开 %@",
        .quitApp: "退出 %@",
        .showPanel: "显示计薪面板",
        .aboutApp: "关于 %@",
        .editMenu: "编辑",
        .undo: "撤销",
        .redo: "重做",
        .cut: "剪切",
        .copy: "复制",
        .paste: "粘贴",
        .selectAll: "全选"
    ]

    private static let english: [LKey: String] = [
        .cancel: "Cancel",
        .reset: "Reset",
        .done: "Done",
        .back: "Back",
        .settings: "Settings",
        .appearanceSystem: "System",
        .appearanceLight: "Light",
        .appearanceDark: "Dark",
        .appearanceHelp: "Appearance: %@ · Click to cycle",
        .appearanceToast: "Appearance: %@",
        .language: "Language",
        .languageHint: "Applies immediately",
        .currency: "Currency",
        .bigMacCounterTitle: "How many Big Macs u got?",
        .bigMacCounterHint: "Turns this session's earnings into Big Macs scattered beside the amount. Hover to see the count.",
        .bigMacHoverCount: "%d Big Macs",
        .bigMacAccessibility: "%d Big Macs earned this session",
        .bigMacPriceHint: "The Economist Big Mac Index · Jan 2025 · %@ %@",

        .earnedThisSession: "Earned this session",
        .sessionCurrentLabel: "This session",
        .totalLabel: "All time",
        .dailyTarget: "Daily target",
        .perSecond: "Per second",
        .perMinute: "Per minute",
        .perHour: "Per hour",
        .clockIn: "Clock in",
        .clockOut: "Clock out",
        .startOvertime: "Start overtime",
        .endOvertime: "End overtime",
        .actionInShort: "Clock in",
        .actionOutShort: "Clock out",
        .actionOvertimeShort: "Overtime",
        .actionDoneShort: "Finish",
        .timelineClockIn: "Clock in",
        .timelineClockOut: "Clock out",
        .timelineOvertime: "Overtime",
        .timelineDone: "Done",
        .timelineInShort: "In",
        .timelineOutShort: "Out",
        .timelineOTShort: "OT",
        .timelineDoneShort: "Done",
        .phaseTitleIdle: "Ready to clock in",
        .phaseTitleWorking: "Earning regular pay",
        .phaseTitleClockedOut: "Clocked out",
        .phaseTitleOvertime: "Earning overtime pay",
        .phaseTitleFinished: "Session finished",
        .resetThisSession: "Reset session",
        .resetConfirmTitle: "Reset this session?",
        .resetConfirmMessage: "This session's %@ will be cleared. Your all-time total is kept.",

        .settingsTitle: "Settings",
        .preferences: "Preferences",
        .paySection: "Pay",
        .ratesSection: "Rates",
        .dataSection: "Data",
        .updatesSection: "Updates",
        .autoCheckUpdates: "Check for updates automatically",
        .autoCheckUpdatesHint: "Checks GitHub Releases at launch and every few hours.",
        .autoInstallUpdates: "Download and install automatically",
        .autoInstallUpdatesHint: "Downloads, verifies and relaunches into a new version. If anything fails, the current version is kept.",
        .checkForUpdates: "Check for updates",
        .installUpdate: "Install update",
        .updateRetry: "Retry",
        .updateStatusDisabled: "Automatic checks are off",
        .updateStatusIdle: "Not checked yet",
        .updateStatusChecking: "Checking for updates…",
        .updateStatusUpToDate: "You're up to date",
        .updateStatusAvailable: "Version %@ is available",
        .updateStatusDownloading: "Downloading %@…",
        .updateStatusPreparing: "Preparing update…",
        .updateStatusInstalling: "Restarting to finish the update…",
        .updateFailureNetwork: "Couldn't reach GitHub. Try again.",
        .updateFailureMissingAsset: "This release has no macOS installer.",
        .updateFailureChecksum: "The update package failed verification. Installation was cancelled.",
        .updateFailureUnsafe: "This install location can't be updated automatically. Download from Releases.",
        .updateFailurePackage: "The update package is invalid. Installation was cancelled.",
        .updateFailureInstall: "Automatic install failed. Download from Releases.",
        .updatePromptTitle: "Update to %@",
        .updatePromptHint: "Version %@ is available. Click to install and restart.",
        .paySavedHint: "Saved as you type",
        .monthlySalary: "Monthly salary",
        .workdaysPerMonth: "Workdays per month",
        .hoursPerDay: "Hours per day",
        .overtimeHourly: "Overtime rate",
        .fillSuggestedRate: "Fill 1.5× (%@)",
        .currencyDisplayOnlyNote: "Changing currency only changes the symbol. Entered amounts are not converted.",
        .perMonthSuffix: "mo",
        .perHourSuffix: "hr",
        .daysSuffix: "days",
        .hoursSuffix: "hours",
        .fullResetTitle: "Reset everything",
        .fullResetCaption: "All-time total %@. This cannot be undone.",
        .fullResetAction: "Clear",
        .fullResetConfirmTitle: "Reset everything?",
        .fullResetConfirmMessage: "Your all-time total of %@ (including %@ from this session) will be permanently cleared, and timing will stop. This cannot be undone.",
        .fullResetConfirmAction: "Reset all",

        .statusAccessibilityLabel: "Live earnings",
        .statusAccessibilityValue: "%@, %@",
        .statusTooltip: "%@ · %@ · %@",
        .openApp: "Open %@",
        .quitApp: "Quit %@",
        .showPanel: "Show Earnings Panel",
        .aboutApp: "About %@",
        .editMenu: "Edit",
        .undo: "Undo",
        .redo: "Redo",
        .cut: "Cut",
        .copy: "Copy",
        .paste: "Paste",
        .selectAll: "Select All"
    ]
}
