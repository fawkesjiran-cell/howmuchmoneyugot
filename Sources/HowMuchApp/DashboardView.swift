import Foundation
import HowMuchCore
import SwiftUI

/// Signal Ledger dashboard: flat paper, one hairline card, pine for money and
/// ember only when the session is earning overtime.
struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    let openSettings: () -> Void

    @State private var showResetAlert = false
    @State private var themeNotice: ThemePreference?
    @State private var themeNoticeDismissal: DispatchWorkItem?

    private var snapshot: EarningsSnapshot { model.snapshot }
    private var isOvertime: Bool { snapshot.phase == .overtime }

    var body: some View {
        VStack(spacing: 8) {
            header

            VStack(spacing: 8) {
                balance
                target
                rates
                actions
                rail
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .frame(width: 392, height: 320)
        .overlay(alignment: .topTrailing) {
            if let themeNotice {
                Text(model.t(.appearanceToast, model.t(themeNotice.titleKey)))
                    .font(AppFont.geist(9.5, .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(height: 21)
                    .background(
                        Capsule()
                            .fill(Palette.surface)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Palette.line, lineWidth: 0.8)
                    )
                    .shadow(color: Palette.ink.opacity(0.05), radius: 4, y: 1)
                    .padding(.top, 42)
                    .padding(.trailing, 32)
                    .transition(
                        .opacity.combined(
                            with: .scale(scale: 0.95, anchor: .topTrailing)
                        )
                    )
                    .allowsHitTesting(false)
            }
        }
        .onDisappear {
            themeNoticeDismissal?.cancel()
            themeNotice = nil
        }
        .alert(model.t(.resetConfirmTitle), isPresented: $showResetAlert) {
            Button(model.t(.cancel), role: .cancel) {}
            Button(model.t(.reset), role: .destructive) {
                model.resetSession()
            }
        } message: {
            Text(model.t(.resetConfirmMessage, model.money(snapshot.total)))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            LogoMark(symbol: model.currency.symbol)

            Text(AppMetadata.displayName)
                .font(AppFont.geist(14, .semibold))
                .tracking(-0.1)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                HeaderIconButton(
                    icon: model.theme.symbolName,
                    isEnabled: true,
                    help: model.t(
                        .appearanceHelp,
                        model.t(model.theme.titleKey)
                    )
                ) {
                    model.cycleTheme()
                    showThemeNotice()
                }

                HeaderIconButton(
                    icon: "arrow.counterclockwise",
                    isEnabled: model.session.hasRecordedTime,
                    help: model.t(.resetThisSession)
                ) {
                    showResetAlert = true
                }

                HeaderIconButton(
                    icon: "gearshape",
                    isEnabled: true,
                    help: model.t(.settings)
                ) {
                    openSettings()
                }
            }
        }
        .padding(.horizontal, 32)
        .frame(height: 36)
    }

    private func showThemeNotice() {
        themeNoticeDismissal?.cancel()

        withAnimation(.easeOut(duration: 0.14)) {
            themeNotice = model.theme
        }

        let work = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.18)) {
                themeNotice = nil
            }
        }
        themeNoticeDismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35, execute: work)
    }

    // MARK: - Balance

    private var balance: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                StatusDot(phase: snapshot.phase, help: model.phaseTitle(snapshot.phase))

                Text(model.t(.sessionCurrentLabel))
                    .font(AppFont.geist(9.5, .medium))
                    .foregroundStyle(Palette.muted)

                Text("·")
                    .font(AppFont.geist(9.5, .medium))
                    .foregroundStyle(Palette.faint)

                Text(model.phaseTitle(snapshot.phase))
                    .font(AppFont.geist(9.5, .semibold))
                    .foregroundStyle(
                        isOvertime
                            ? Palette.ember
                            : (snapshot.phase == .idle ? Palette.faint : Palette.secondary)
                    )
                    .lineLimit(1)

                if isOvertime {
                    overtimeChip
                }

                Spacer(minLength: 0)
            }
            .frame(height: 12)

            OvertimeAmount(
                symbol: model.currency.symbol,
                amount: model.amount(snapshot.total),
                isOvertime: isOvertime
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 46, alignment: .leading)
            .padding(.top, 7)

            HStack(spacing: 5) {
                Text(Fmt.duration(snapshot.totalSeconds))
                    .font(AppFont.numbers(10.5, .medium))
                    .foregroundStyle(Palette.muted)

                Circle()
                    .fill(Palette.faint)
                    .frame(width: 2, height: 2)

                Text("\(model.t(.totalLabel)) \(model.money(model.totalEarned))")
                    .font(AppFont.numbers(10.5, .medium))
                    .foregroundStyle(Palette.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: 14)
            .padding(.top, 5)
        }
        .frame(height: 86, alignment: .bottom)
    }

    private var overtimeChip: some View {
        let multiplier = model.settings.overtimeMultiplier

        return Group {
            if multiplier.isFinite, multiplier > 0 {
                Text(String(format: "×%.1f", multiplier))
                    .font(AppFont.geist(8, .semibold))
                    .foregroundStyle(Palette.ember)
                    .padding(.horizontal, 5)
                    .frame(height: 14)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Palette.emberSoft)
                    )
            }
        }
    }

    // MARK: - Target

    private var target: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Text("\(model.t(.dailyTarget)) · \(model.money(model.settings.dailyPay))")
                    .font(AppFont.geist(9.5, .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Text("\(targetPercent)%")
                    .font(AppFont.numbers(9.5, .semibold))
                    .foregroundStyle(isOvertime ? Palette.ember : Palette.ink)
            }
            .frame(height: 12)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.sunken)

                    Capsule()
                        .fill(Palette.emberFill)
                        .frame(width: proxy.size.width * targetProgress)
                }
            }
            .frame(height: 4)
        }
        .frame(height: 22, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.t(.dailyTarget)) \(targetPercent)%")
    }

    private var targetProgress: Double {
        guard model.settings.dailyPay > 0 else { return 0 }
        return min(max(snapshot.total / model.settings.dailyPay, 0), 1)
    }

    private var targetPercent: Int {
        guard model.settings.dailyPay > 0 else { return 0 }
        return Int((snapshot.total / model.settings.dailyPay * 100).rounded())
    }

    // MARK: - Rates

    private var rateTint: Color {
        isOvertime ? Palette.ember : Palette.ink
    }

    private var rates: some View {
        HStack(spacing: 0) {
            RateMetric(
                label: model.t(.perSecond),
                symbol: model.currency.symbol,
                value: Fmt.rate(snapshot.activePerSecondRate, decimals: 4),
                tint: rateTint
            )

            rateDivider

            RateMetric(
                label: model.t(.perMinute),
                symbol: model.currency.symbol,
                value: Fmt.rate(snapshot.activePerMinuteRate, decimals: 3),
                tint: rateTint
            )

            rateDivider

            RateMetric(
                label: model.t(.perHour),
                symbol: model.currency.symbol,
                value: model.amount(snapshot.activeHourlyRate),
                tint: rateTint
            )
        }
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isOvertime ? Palette.ember.opacity(0.18) : Palette.line,
                    lineWidth: 0.8
                )
        )
    }

    private var rateDivider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(width: 0.8)
            .padding(.vertical, 9)
    }

    // MARK: - Actions

    private var clockInStyle: ActionTile.Style {
        guard model.canClockIn else { return .ghost }
        // After clocking out, starting overtime is the primary next step. Clock
        // in stays available as a secondary action (it archives this session and
        // starts a fresh one) so the row never shows two filled primaries.
        return snapshot.phase == .clockedOut ? .ghost : .solid
    }

    private var actions: some View {
        HStack(spacing: 8) {
            ActionTile(
                title: model.t(.actionInShort),
                icon: "play.fill",
                style: clockInStyle,
                isEnabled: model.canClockIn
            ) {
                model.clockIn()
            }

            ActionTile(
                title: model.t(.actionOutShort),
                icon: "stop.fill",
                style: model.canClockOut ? .solid : .ghost,
                isEnabled: model.canClockOut
            ) {
                model.clockOut()
            }

            ActionTile(
                title: model.t(.startOvertime),
                icon: "flame",
                style: model.canStartOvertime ? .solid : .ghost,
                isEnabled: model.canStartOvertime,
                showsEmberHint: !model.canStartOvertime && snapshot.phase == .working
            ) {
                model.startOvertime()
            }

            ActionTile(
                title: model.t(.actionDoneShort),
                icon: "checkmark",
                style: model.canEndOvertime ? .solid : .ghost,
                isEnabled: model.canEndOvertime
            ) {
                model.endOvertime()
            }
        }
        .frame(height: 40)
    }

    // MARK: - Rail

    private var rail: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let inset = proxy.size.width * 0.125
                let length = proxy.size.width * 0.75

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Palette.line)
                        .frame(width: length, height: 1)
                        .offset(x: inset, y: 5)

                    // The regular (In → Out) and overtime (Out → OT/Done)
                    // segments have separate extents so a clocked-out day does
                    // not prematurely turn the line ember.
                    let regularProgress = min(railProgress, 1.0 / 3.0)
                    let overtimeProgress = max(0, railProgress - 1.0 / 3.0)

                    if regularProgress > 0 {
                        Rectangle()
                            .fill(Palette.secondary.opacity(0.55))
                            .frame(width: length * regularProgress, height: 1)
                            .offset(x: inset, y: 5)
                    }

                    if overtimeProgress > 0 {
                        Rectangle()
                            .fill(Palette.emberFill)
                            .frame(width: length * overtimeProgress, height: 1)
                            .offset(x: inset + length / 3, y: 5)
                    }
                }
            }

            HStack(spacing: 0) {
                RailStop(
                    label: model.t(.timelineInShort),
                    time: Fmt.time(model.session.normalStartedAt),
                    state: inState,
                    accent: Palette.secondary
                )

                RailStop(
                    label: model.t(.timelineOutShort),
                    time: Fmt.time(model.session.normalEndedAt),
                    state: outState,
                    accent: Palette.secondary
                )

                RailStop(
                    label: model.t(.timelineOTShort),
                    time: Fmt.time(model.session.overtimeStartedAt),
                    state: overtimeState,
                    accent: Palette.ember
                )

                RailStop(
                    label: model.t(.timelineDoneShort),
                    time: Fmt.time(model.session.overtimeEndedAt),
                    state: doneState,
                    accent: Palette.secondary
                )
            }
        }
        .frame(height: 28)
    }

    private var railProgress: CGFloat {
        switch snapshot.phase {
        case .idle, .working: return 0
        case .clockedOut: return 1.0 / 3.0
        case .overtime: return 2.0 / 3.0
        case .finished: return 1
        }
    }

    private var inState: RailState {
        switch snapshot.phase {
        case .idle: return .future
        case .working: return .active
        case .clockedOut, .overtime, .finished: return .complete
        }
    }

    private var outState: RailState {
        switch snapshot.phase {
        case .idle, .working: return .future
        case .clockedOut: return .active
        case .overtime, .finished: return .complete
        }
    }

    private var overtimeState: RailState {
        switch snapshot.phase {
        case .idle, .working, .clockedOut: return .future
        case .overtime: return .active
        case .finished: return .complete
        }
    }

    private var doneState: RailState {
        snapshot.phase == .finished ? .active : .future
    }
}

// MARK: - Pieces

struct LogoMark: View {
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.primary)

            Text(symbol)
                .font(AppFont.geist(13, .semibold))
                .foregroundStyle(Palette.onPrimary)
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}

struct HeaderIconButton: View {
    let icon: String
    let isEnabled: Bool
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    isEnabled
                        ? Palette.secondary
                        : Palette.faint.opacity(0.45)
                )
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(hovering && isEnabled ? Palette.surfaceMuted : Color.clear)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

struct StatusDot: View {
    let phase: WorkPhase
    let help: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private var tint: Color {
        switch phase {
        case .working: return Palette.primary
        case .overtime: return Palette.ember
        case .clockedOut, .finished, .idle: return Palette.faint
        }
    }

    private var isPulsing: Bool {
        phase == .working || phase == .overtime
    }

    var body: some View {
        ZStack {
            if isPulsing, !reduceMotion {
                Circle()
                    .stroke(tint.opacity(0.35), lineWidth: 0.8)
                    .frame(width: 5, height: 5)
                    .scaleEffect(expanded ? 2.1 : 1)
                    .opacity(expanded ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.8).repeatForever(autoreverses: false),
                        value: expanded
                    )
            }

            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
        }
        .frame(width: 5, height: 5)
        .onAppear { expanded = true }
        .help(help)
        .accessibilityHidden(true)
    }
}

struct RateMetric: View {
    let label: String
    let symbol: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFont.geist(8.5, .medium))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(symbol)
                    .font(AppFont.geist(8.5, .semibold))
                    .foregroundStyle(Palette.faint)

                Text(value)
                    .font(AppFont.numbers(14.5, .semibold))
                    .tracking(-0.25)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

struct ActionTile: View {
    enum Style {
        case ghost
        case solid
    }

    let title: String
    let icon: String
    let style: Style
    let isEnabled: Bool
    var showsEmberHint: Bool = false
    let action: () -> Void

    @State private var hovering = false

    private var textColor: Color {
        guard isEnabled else { return Palette.muted.opacity(0.55) }

        switch style {
        case .ghost: return Palette.muted
        case .solid: return Palette.onEmber
        }
    }

    private var iconColor: Color {
        guard isEnabled else {
            return showsEmberHint
                ? Palette.ember.opacity(0.55)
                : Palette.muted.opacity(0.45)
        }

        switch style {
        case .ghost: return Palette.muted
        case .solid: return Palette.onEmber
        }
    }

    private var fill: Color {
        guard isEnabled else { return .clear }

        switch style {
        case .ghost: return hovering ? Palette.surfaceMuted : .clear
        case .solid: return hovering ? Palette.emberFill.opacity(0.90) : Palette.emberFill
        }
    }

    private var border: Color {
        guard isEnabled else {
            return showsEmberHint
                ? Palette.ember.opacity(0.20)
                : Palette.line
        }

        switch style {
        case .ghost: return Palette.line
        case .solid: return Palette.emberFill
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(AppFont.geist(10, style == .ghost ? .medium : .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(border, lineWidth: 0.8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .onHover { hovering = $0 }
        .help(title)
    }
}

enum RailState {
    case future
    case active
    case complete
}

struct RailStop: View {
    let label: String
    let time: String
    let state: RailState
    let accent: Color

    private var nodeColor: Color {
        switch state {
        case .future: return Palette.lineStrong
        case .active, .complete: return accent
        }
    }

    private var labelColor: Color {
        state == .future ? Palette.faint : Palette.muted
    }

    private var timeColor: Color {
        switch state {
        case .future: return Palette.faint
        case .active: return accent
        case .complete: return Palette.ink
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if state == .active {
                    Circle()
                        .fill(accent.opacity(0.16))
                        .frame(width: 12, height: 12)
                }

                Circle()
                    .fill(nodeColor)
                    .frame(width: 6, height: 6)
            }
            .frame(height: 6)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(AppFont.geist(8.5, .medium))
                    .foregroundStyle(labelColor)

                Text(time)
                    .font(AppFont.numbers(10.5, .semibold))
                    .foregroundStyle(timeColor)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(time)")
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
