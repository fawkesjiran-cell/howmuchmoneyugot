import HowMuchCore

enum LKey: Hashable {
    // Brand & common
    case brand
    case tagline
    case cancel
    case reset
    case done
    case back
    case settings
    case preferences
    case language
    case languageHint
    case currency
    case currencyHint

    // Dashboard
    case earnedThisSession
    case currentRateInline
    case dailyTarget
    case currentEarningRate
    case overtimeRate
    case regularRate
    case perSecond
    case perMinute
    case perHour
    case clockIn
    case clockOut
    case startOvertime
    case endOvertime
    case timelineClockIn
    case timelineClockOut
    case timelineOvertime
    case timelineDone
    case resetThisSession
    case regularFooter
    case overtimeFooter
    case phaseBadgeIdle
    case phaseBadgeWorking
    case phaseBadgeClockedOut
    case phaseBadgeOvertime
    case phaseBadgeFinished
    case phaseTitleIdle
    case phaseTitleWorking
    case phaseTitleClockedOut
    case phaseTitleOvertime
    case phaseTitleFinished
    case phaseHintIdle
    case phaseHintWorking
    case phaseHintClockedOut
    case phaseHintOvertime
    case phaseHintFinished
    case restartConfirmTitle
    case restartConfirmMessage
    case restartAction
    case resetConfirmTitle
    case resetConfirmMessage

    // Settings
    case settingsTitle
    case settingsSubtitle
    case incomeInputSection
    case monthlySalary
    case monthlySalaryHint
    case workdaysPerMonth
    case workdaysHint
    case hoursPerDay
    case hoursHint
    case overtimeHourly
    case overtimeHourlyHint
    case fillSuggestedRate
    case invalidIncome
    case calculatedRates
    case regularHourly
    case formulaNote
    case sessionTotal
    case privacyNote
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
        .brand: "进账",
        .tagline: "看见每一秒的价值",
        .cancel: "取消",
        .reset: "重置",
        .done: "完成",
        .back: "返回",
        .settings: "设置",
        .preferences: "偏好设置",
        .language: "语言",
        .languageHint: "界面会立即切换",
        .currency: "货币单位",
        .currencyHint: "只改变显示的货币符号",

        .earnedThisSession: "本次已赚",
        .currentRateInline: "当前 %@/时",
        .dailyTarget: "日薪目标",
        .currentEarningRate: "此刻收入速率",
        .overtimeRate: "加班费率",
        .regularRate: "正常费率",
        .perSecond: "每秒",
        .perMinute: "每分",
        .perHour: "每小时",
        .clockIn: "打卡上班",
        .clockOut: "打卡下班",
        .startOvertime: "开始加班",
        .endOvertime: "结束加班",
        .timelineClockIn: "上班",
        .timelineClockOut: "下班",
        .timelineOvertime: "加班",
        .timelineDone: "收工",
        .resetThisSession: "重置本次",
        .regularFooter: "普通 %@/时",
        .overtimeFooter: "加班 %@/时",
        .phaseBadgeIdle: "待开始",
        .phaseBadgeWorking: "计薪中",
        .phaseBadgeClockedOut: "已下班",
        .phaseBadgeOvertime: "加班中",
        .phaseBadgeFinished: "已完成",
        .phaseTitleIdle: "待打卡",
        .phaseTitleWorking: "正常计薪中",
        .phaseTitleClockedOut: "已打卡下班",
        .phaseTitleOvertime: "加班计薪中",
        .phaseTitleFinished: "本次已完成",
        .phaseHintIdle: "点击「打卡上班」，开始记录今天的收入",
        .phaseHintWorking: "正常计薪中，点击「打卡下班」结束本轮",
        .phaseHintClockedOut: "已下班，可以开始加班，或重新打卡",
        .phaseHintOvertime: "加班计薪中，点击「结束加班」完成本次",
        .phaseHintFinished: "本次已完成，再次上班会开启新记录",
        .restartConfirmTitle: "开始新的一次计薪？",
        .restartConfirmMessage: "本次已累计 %@，重新打卡会将这笔记录清零。",
        .restartAction: "重新开始",
        .resetConfirmTitle: "重置本次计薪？",
        .resetConfirmMessage: "当前累计的 %@ 将清零，且无法恢复。",

        .settingsTitle: "收入与工时",
        .settingsSubtitle: "修改后立即生效",
        .incomeInputSection: "收入输入",
        .monthlySalary: "普通月薪",
        .monthlySalaryHint: "税前或到手均可",
        .workdaysPerMonth: "每月工作日",
        .workdaysHint: "用于换算普通时薪",
        .hoursPerDay: "每日工时",
        .hoursHint: "正常工作的时长",
        .overtimeHourly: "加班时薪",
        .overtimeHourlyHint: "可独立于普通时薪",
        .fillSuggestedRate: "按 1.5× 填入 %@",
        .invalidIncome: "月薪与工时需大于 0",
        .calculatedRates: "换算结果",
        .regularHourly: "普通时薪",
        .formulaNote: "按每月 %@ 天、每天 %@ 小时换算",
        .sessionTotal: "本次累计",
        .privacyNote: "计时状态与收入设置只保存在这台 Mac 上；关闭应用后再次打开，会接着上次的状态继续计时。",
        .currencyDisplayOnlyNote: "切换货币只改变显示符号，不会换算已填写的金额。",
        .perMonthSuffix: "月",
        .perHourSuffix: "时",
        .daysSuffix: "天",
        .hoursSuffix: "小时",

        .statusAccessibilityLabel: "进账计薪",
        .statusAccessibilityValue: "%@，%@",
        .statusTooltip: "%@ · %@ · %@",
        .openApp: "打开进账",
        .quitApp: "退出进账",
        .showPanel: "显示计薪面板",
        .aboutApp: "关于进账",
        .editMenu: "编辑",
        .undo: "撤销",
        .redo: "重做",
        .cut: "剪切",
        .copy: "复制",
        .paste: "粘贴",
        .selectAll: "全选"
    ]

    private static let english: [LKey: String] = [
        .brand: "JinZhang",
        .tagline: "See every second pay off",
        .cancel: "Cancel",
        .reset: "Reset",
        .done: "Done",
        .back: "Back",
        .settings: "Settings",
        .preferences: "Preferences",
        .language: "Language",
        .languageHint: "Applies immediately",
        .currency: "Currency",
        .currencyHint: "Changes the currency symbol only",

        .earnedThisSession: "Earned this session",
        .currentRateInline: "Now %@/hr",
        .dailyTarget: "Daily target",
        .currentEarningRate: "Current earning rate",
        .overtimeRate: "Overtime rate",
        .regularRate: "Regular rate",
        .perSecond: "Per second",
        .perMinute: "Per minute",
        .perHour: "Per hour",
        .clockIn: "Clock in",
        .clockOut: "Clock out",
        .startOvertime: "Start overtime",
        .endOvertime: "End overtime",
        .timelineClockIn: "Clock in",
        .timelineClockOut: "Clock out",
        .timelineOvertime: "Overtime",
        .timelineDone: "Done",
        .resetThisSession: "Reset session",
        .regularFooter: "Regular %@/hr",
        .overtimeFooter: "Overtime %@/hr",
        .phaseBadgeIdle: "Ready",
        .phaseBadgeWorking: "Earning",
        .phaseBadgeClockedOut: "Clocked out",
        .phaseBadgeOvertime: "Overtime",
        .phaseBadgeFinished: "Finished",
        .phaseTitleIdle: "Ready to clock in",
        .phaseTitleWorking: "Earning regular pay",
        .phaseTitleClockedOut: "Clocked out",
        .phaseTitleOvertime: "Earning overtime pay",
        .phaseTitleFinished: "Session finished",
        .phaseHintIdle: "Tap Clock in to start tracking today's earnings",
        .phaseHintWorking: "Regular pay is running. Tap Clock out to end this shift",
        .phaseHintClockedOut: "Clocked out. Start overtime, or clock in again",
        .phaseHintOvertime: "Overtime pay is running. Tap End overtime when done",
        .phaseHintFinished: "Session complete. Clocking in again starts a new record",
        .restartConfirmTitle: "Start a new session?",
        .restartConfirmMessage: "This session has earned %@. Clocking in again will clear this record.",
        .restartAction: "Start over",
        .resetConfirmTitle: "Reset this session?",
        .resetConfirmMessage: "The current total of %@ will be cleared and cannot be restored.",

        .settingsTitle: "Income & hours",
        .settingsSubtitle: "Changes apply immediately",
        .incomeInputSection: "Income",
        .monthlySalary: "Monthly salary",
        .monthlySalaryHint: "Gross or net pay",
        .workdaysPerMonth: "Workdays per month",
        .workdaysHint: "Used to derive hourly pay",
        .hoursPerDay: "Hours per day",
        .hoursHint: "Regular working hours",
        .overtimeHourly: "Overtime rate",
        .overtimeHourlyHint: "Independent of regular pay",
        .fillSuggestedRate: "Fill 1.5× (%@)",
        .invalidIncome: "Salary and hours must be above 0",
        .calculatedRates: "Calculated rates",
        .regularHourly: "Regular hourly",
        .formulaNote: "Based on %@ workdays/month and %@ hours/day",
        .sessionTotal: "Session total",
        .privacyNote: "Timer state and pay settings stay on this Mac. Reopening the app continues the current session.",
        .currencyDisplayOnlyNote: "Changing currency only changes the symbol. Entered amounts are not converted.",
        .perMonthSuffix: "mo",
        .perHourSuffix: "hr",
        .daysSuffix: "days",
        .hoursSuffix: "hours",

        .statusAccessibilityLabel: "JinZhang earnings",
        .statusAccessibilityValue: "%@, %@",
        .statusTooltip: "%@ · %@ · %@",
        .openApp: "Open JinZhang",
        .quitApp: "Quit JinZhang",
        .showPanel: "Show Earnings Panel",
        .aboutApp: "About JinZhang",
        .editMenu: "Edit",
        .undo: "Undo",
        .redo: "Redo",
        .cut: "Cut",
        .copy: "Copy",
        .paste: "Paste",
        .selectAll: "Select All"
    ]
}
