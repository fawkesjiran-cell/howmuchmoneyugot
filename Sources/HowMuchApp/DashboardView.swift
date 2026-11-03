import HowMuchCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    let openSettings: () -> Void

    @State private var showResetAlert = false

    private var snapshot: EarningsSnapshot { model.snapshot }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 13) {
                heroCard
                rateCard
                actionBar
                timelineCard
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 16)
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
        HStack(spacing: 10) {
            LogoMark(symbol: model.currency.symbol)

            Text(AppMetadata.displayName)
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 4)

            HeaderIconButton(
                icon: "arrow.counterclockwise",
                isEnabled: model.session.hasRecordedTime,
                help: model.t(.resetThisSession)
            ) {
                showResetAlert = true
            }

            HeaderIconButton(
                icon: "gearshape.fill",
                isEnabled: true,
                help: model.t(.settings)
            ) {
                openSettings()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Money

    private var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Palette.heroTop, Palette.heroBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Palette.heroText.opacity(0.055), lineWidth: 1)
                .frame(width: 232, height: 232)
                .offset(x: 142, y: -72)
            Circle()
                .fill(Palette.heroText.opacity(0.03))
                .frame(width: 156, height: 156)
                .offset(x: 152, y: 76)
            Text(model.currency.symbol)
                .font(.system(size: 152, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.028))
                .offset(x: 128, y: 64)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    StatusDot(
                        phase: snapshot.phase,
                        help: model.phaseTitle(snapshot.phase)
                    )

                    Text(model.t(.sessionCurrentLabel))
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(
                            showOvertimeRate
                                ? Color(hex: 0xFFD98A)
                                : Palette.heroMuted
                        )

                    Spacer(minLength: 4)
                }
                .padding(.bottom, 7)

                OvertimeAmount(
                    symbol: model.currency.symbol,
                    amount: model.amount(snapshot.total),
                    isOvertime: showOvertimeRate
                )
                .padding(.bottom, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(model.t(.earnedThisSession)) \(model.money(snapshot.total))"
                )

                HStack(spacing: 8) {
                    Label(Fmt.duration(snapshot.totalSeconds), systemImage: "timer")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.heroMuted)

                    Spacer(minLength: 6)

                    HStack(spacing: 5) {
                        Text(model.t(.totalLabel))
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.heroMuted)
                        Text(model.money(model.totalEarned))
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Palette.heroText.opacity(0.94))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.09))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7)
                            )
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(model.t(.totalLabel)) \(model.money(model.totalEarned))"
                    )
                }
            }
            .padding(18)
        }
        .frame(height: 156)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .strokeBorder(
                    showOvertimeRate
                        ? Color(hex: 0xFFB13B).opacity(0.46)
                        : Color.white.opacity(0.08),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Palette.shadow.opacity(0.5), radius: 15, x: 0, y: 8)
    }

    // MARK: - Rates

    private var showOvertimeRate: Bool {
        snapshot.phase == .overtime
    }

    private var rateCard: some View {
        HStack(spacing: 0) {
            RateMetric(
                label: model.t(.perSecond),
                symbol: model.currency.symbol,
                value: model.amount(snapshot.activePerSecondRate, precise: true),
                tint: showOvertimeRate ? Palette.goldDeep : Palette.ink
            )
            verticalRule
            RateMetric(
                label: model.t(.perMinute),
                symbol: model.currency.symbol,
                value: model.amount(snapshot.activePerMinuteRate),
                tint: showOvertimeRate ? Palette.goldDeep : Palette.ink
            )
            verticalRule
            RateMetric(
                label: model.t(.perHour),
                symbol: model.currency.symbol,
                value: model.amount(snapshot.activeHourlyRate),
                tint: showOvertimeRate ? Palette.goldDeep : Palette.ink
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardSurface(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    showOvertimeRate ? Palette.gold.opacity(0.32) : Color.clear,
                    lineWidth: 0.8
                )
        )
    }

    private var verticalRule: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(width: 0.8, height: 25)
            .padding(.horizontal, 9)
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 3) {
            ActionTile(
                title: model.t(.actionInShort),
                help: model.t(.clockIn),
                icon: "play.fill",
                style: .green,
                isEnabled: model.canClockIn
            ) {
                model.clockIn()
            }

            ActionTile(
                title: model.t(.actionOutShort),
                help: model.t(.clockOut),
                icon: "stop.fill",
                style: .ink,
                isEnabled: model.canClockOut
            ) {
                model.clockOut()
            }

            ActionTile(
                title: model.t(.actionOvertimeShort),
                help: model.t(.startOvertime),
                icon: "bolt.fill",
                style: .gold,
                isEnabled: model.canStartOvertime
            ) {
                model.startOvertime()
            }

            ActionTile(
                title: model.t(.actionDoneShort),
                help: model.t(.endOvertime),
                icon: "checkmark",
                style: .ink,
                isEnabled: model.canEndOvertime
            ) {
                model.endOvertime()
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(Palette.line, lineWidth: 0.8)
                )
        )
    }

    // MARK: - Timeline

    private var timelineCard: some View {
        HStack(spacing: 0) {
            TimelineIcon(
                icon: "play.fill",
                time: Fmt.time(model.session.normalStartedAt),
                label: model.t(.timelineClockIn),
                isActive: model.session.phase == .working,
                tint: Palette.normal
            )
            timelineRule
            TimelineIcon(
                icon: "stop.fill",
                time: Fmt.time(model.session.normalEndedAt),
                label: model.t(.timelineClockOut),
                isActive: false,
                tint: Palette.normal
            )
            timelineRule
            TimelineIcon(
                icon: "bolt.fill",
                time: Fmt.time(model.session.overtimeStartedAt),
                label: model.t(.timelineOvertime),
                isActive: model.session.phase == .overtime,
                tint: Palette.gold
            )
            timelineRule
            TimelineIcon(
                icon: "checkmark",
                time: Fmt.time(model.session.overtimeEndedAt),
                label: model.t(.timelineDone),
                isActive: false,
                tint: Palette.gold
            )
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 6)
        .cardSurface(cornerRadius: 15)
    }

    private var timelineRule: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(width: 0.8, height: 22)
    }
}

// MARK: - Components

struct LogoMark: View {
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Palette.normal, Palette.normalDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            Text(symbol)
                .font(.system(size: symbol.count > 1 ? 12.5 : 17, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.heroText)
                .offset(y: -0.5)
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 3, height: 3)
                .offset(x: -7.5, y: -8.5)
        }
        .frame(width: 34, height: 34)
        .shadow(color: Palette.normal.opacity(0.22), radius: 6, x: 0, y: 3)
    }
}

struct StatusDot: View {
    let phase: WorkPhase
    let help: String

    @State private var pulsing = false

    private var color: Color {
        switch phase {
        case .working: return Color(hex: 0x7DE2B1)
        case .overtime: return Color(hex: 0xF5CB7A)
        case .clockedOut, .finished: return Palette.heroText.opacity(0.46)
        case .idle: return Palette.heroText.opacity(0.30)
        }
    }

    var body: some View {
        ZStack {
            if phase.isEarning {
                Circle()
                    .fill(color.opacity(0.30))
                    .frame(width: 13, height: 13)
                    .scaleEffect(pulsing ? 1.45 : 0.50)
                    .opacity(pulsing ? 0 : 1)
            }
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
        .frame(width: 9, height: 9)
        .help(help)
        .accessibilityLabel(help)
        .onAppear(perform: startPulse)
        .onChange(of: phase) { _ in startPulse() }
    }

    private func startPulse() {
        pulsing = false
        guard phase.isEarning else { return }
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulsing = true
        }
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
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(isEnabled ? Palette.secondary : Palette.tertiary.opacity(0.45))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Palette.surface)
                        .overlay(Circle().strokeBorder(Palette.line, lineWidth: 0.8))
                )
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(hovering && isEnabled ? 0.055 : 0))
                )
                .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

struct RateMetric: View {
    let label: String
    let symbol: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(symbol)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint.opacity(0.55))
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActionTile: View {
    enum Style {
        case green
        case gold
        case ink
    }

    let title: String
    let help: String
    let icon: String
    let style: Style
    let isEnabled: Bool
    let action: () -> Void

    @State private var hovering = false

    private var foreground: Color {
        guard isEnabled else { return Palette.tertiary.opacity(0.6) }
        switch style {
        case .green: return Palette.heroText
        case .gold: return Color(hex: 0x2B1A04)
        case .ink: return Palette.buttonInkText
        }
    }

    private var background: AnyShapeStyle {
        guard isEnabled else { return AnyShapeStyle(Color.clear) }
        switch style {
        case .green:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Palette.normalDeep, Palette.normal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .gold:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Palette.goldDeep, Palette.gold],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .ink:
            return AnyShapeStyle(Palette.buttonInk)
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(hovering && isEnabled ? 0.06 : 0))
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

struct TimelineIcon: View {
    let icon: String
    let time: String
    let label: String
    let isActive: Bool
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(time)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(isActive ? tint : (time == "--:--" ? Palette.tertiary.opacity(0.55) : Palette.ink.opacity(0.78)))
        .frame(maxWidth: .infinity)
        .help(label)
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
