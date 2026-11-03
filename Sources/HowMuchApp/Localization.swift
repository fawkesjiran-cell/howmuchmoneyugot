import HowMuchCore

enum LKey: Hashable {
    // Brand & common
    case cancel
    case reset
    case done
    case back
    case settings
    case language
    case languageHint
    case currency

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
        .language: "语言",
        .languageHint: "界面会立即切换",
        .currency: "货币单位",

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
        .phaseTitleIdle: "待打卡",
        .phaseTitleWorking: "正常计薪中",
        .phaseTitleClockedOut: "已打卡下班",
        .phaseTitleOvertime: "加班计薪中",
        .phaseTitleFinished: "本次已完成",
        .resetThisSession: "重置本次",
        .resetConfirmTitle: "重置本次计薪？",
        .resetConfirmMessage: "本次的 %@ 将清零，历史总计会保留。",

        .settingsTitle: "设置",
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
        .language: "Language",
        .languageHint: "Applies immediately",
        .currency: "Currency",

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
        .phaseTitleIdle: "Ready to clock in",
        .phaseTitleWorking: "Earning regular pay",
        .phaseTitleClockedOut: "Clocked out",
        .phaseTitleOvertime: "Earning overtime pay",
        .phaseTitleFinished: "Session finished",
        .resetThisSession: "Reset session",
        .resetConfirmTitle: "Reset this session?",
        .resetConfirmMessage: "This session's %@ will be cleared. Your all-time total is kept.",

        .settingsTitle: "Settings",
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
