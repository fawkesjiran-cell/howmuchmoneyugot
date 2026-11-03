import HowMuchCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    let openSettings: () -> Void

    @State private var pendingConfirmation: Confirmation?

    private enum Confirmation: String, Identifiable {
        case restart
        case reset

        var id: String { rawValue }
    }

    private var snapshot: EarningsSnapshot { model.snapshot }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 12) {
                heroCard
                rateCard
                actionGrid
                hintLine
                timelineCard
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 8)
            footer
        }
        .alert(item: $pendingConfirmation) { confirmation in
            switch confirmation {
            case .restart:
                return Alert(
                    title: Text("开始新的一次计薪？"),
                    message: Text("本次已累计 ¥\(Fmt.money(snapshot.total))，重新打卡会将这笔记录清零。"),
                    primaryButton: .destructive(Text("重新开始")) {
                        model.clockIn()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            case .reset:
                return Alert(
                    title: Text("重置本次计薪？"),
                    message: Text("当前累计的 ¥\(Fmt.money(snapshot.total)) 将清零，且无法恢复。"),
                    primaryButton: .destructive(Text("重置")) {
                        model.resetSession()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            LogoMark()

            VStack(alignment: .leading, spacing: 2) {
                Text("进账")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("看见每一秒的价值")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondary)
            }

            Spacer()

            Button(action: openSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Palette.surface)
                            .overlay(Circle().strokeBorder(Palette.line, lineWidth: 0.8))
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
            .help("收入和工时设置")
            .accessibilityLabel("设置")
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Money

    private var heroCard: some View {
        let progress = cardProgress
        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Palette.heroTop, Palette.heroBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Palette.heroText.opacity(0.055), lineWidth: 1)
                .frame(width: 238, height: 238)
                .offset(x: 142, y: -76)
            Circle()
                .fill(Palette.heroText.opacity(0.035))
                .frame(width: 158, height: 158)
                .offset(x: 152, y: 76)
            Text("¥")
                .font(.system(size: 156, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.028))
                .offset(x: 128, y: 64)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("本次已赚")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(Palette.heroMuted)
                    Spacer()
                    LiveBadge(phase: snapshot.phase)
                }
                .padding(.bottom, 9)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("¥")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.heroText.opacity(0.55))
                    Text(Fmt.money(snapshot.total))
                        .font(.system(size: 43, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.heroText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .padding(.bottom, 7)

                HStack(spacing: 9) {
                    Label(Fmt.duration(snapshot.totalSeconds), systemImage: "timer")
                    Text("·")
                    Text("当前 ¥\(Fmt.money(snapshot.activeHourlyRate))/时")
                }
                .font(.system(size: 10.5, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.heroMuted)
                .padding(.bottom, 17)

                HStack(spacing: 4) {
                    Text("日薪目标")
                    Text("¥\(Fmt.money(model.settings.dailyPay))")
                        .foregroundStyle(Palette.heroText.opacity(0.82))
                    Spacer()
                    Text("\(Int(min(progress, 9.99) * 100))%")
                        .foregroundStyle(Palette.heroText.opacity(0.82))
                }
                .font(.system(size: 9.5, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.heroMuted)
                .padding(.bottom, 6)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Palette.heroText.opacity(0.12))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xE9D8A9), Color(hex: 0xF3C873)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, proxy.size.width * min(progress, 1)))
                    }
                }
                .frame(height: 5)
            }
            .padding(18)
        }
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
        )
        .shadow(color: Palette.shadow.opacity(0.55), radius: 16, x: 0, y: 9)
    }

    private var cardProgress: Double {
        guard model.settings.dailyPay > 0 else { return 0 }
        return max(0, snapshot.total / model.settings.dailyPay)
    }

    // MARK: - Rates

    private var showOvertimeRate: Bool {
        snapshot.phase == .overtime
    }

    private var rateCard: some View {
        VStack(spacing: 10) {
            HStack {
                SmallCapsLabel(text: "此刻收入速率")
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(showOvertimeRate ? Palette.gold : Palette.normal)
                        .frame(width: 5, height: 5)
                    Text(showOvertimeRate ? "加班费率" : "正常费率")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(showOvertimeRate ? Palette.goldDeep : Palette.normal)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(showOvertimeRate ? Palette.goldSoft : Palette.normalSoft)
                )
            }

            HStack(spacing: 0) {
                RateMetric(
                    label: "每秒",
                    value: Fmt.moneyPrecise(snapshot.activePerSecondRate),
                    tint: showOvertimeRate ? Palette.goldDeep : Palette.ink
                )
                verticalRule
                RateMetric(
                    label: "每分",
                    value: Fmt.money(snapshot.activePerMinuteRate),
                    tint: showOvertimeRate ? Palette.goldDeep : Palette.ink
                )
                verticalRule
                RateMetric(
                    label: "每小时",
                    value: Fmt.money(snapshot.activeHourlyRate),
                    tint: showOvertimeRate ? Palette.goldDeep : Palette.ink
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardSurface(cornerRadius: 17)
    }

    private var verticalRule: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(width: 0.8, height: 26)
            .padding(.horizontal, 9)
    }

    // MARK: - Actions

    private var actionGrid: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                PunchButton(
                    title: "打卡上班",
                    icon: "play.fill",
                    style: .green,
                    isEnabled: model.canClockIn
                ) {
                    if model.clockInStartsNewSession && snapshot.total > 0.001 {
                        pendingConfirmation = .restart
                    } else {
                        model.clockIn()
                    }
                }

                PunchButton(
                    title: "打卡下班",
                    icon: "stop.fill",
                    style: .ink,
                    isEnabled: model.canClockOut
                ) {
                    model.clockOut()
                }
            }

            HStack(spacing: 9) {
                PunchButton(
                    title: "开始加班",
                    icon: "bolt.fill",
                    style: .gold,
                    isEnabled: model.canStartOvertime
                ) {
                    model.startOvertime()
                }

                PunchButton(
                    title: "结束加班",
                    icon: "checkmark",
                    style: .ink,
                    isEnabled: model.canEndOvertime
                ) {
                    model.endOvertime()
                }
            }
        }
    }

    private var hintLine: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 9, weight: .medium))
            Text(model.phaseHint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .font(.system(size: 9.5, weight: .medium, design: .rounded))
        .foregroundStyle(Palette.tertiary)
        .padding(.horizontal, 2)
    }

    // MARK: - Timeline

    private var timelineCard: some View {
        HStack(spacing: 0) {
            TimelineMetric(
                label: "上班",
                value: Fmt.time(model.session.normalStartedAt),
                isActive: model.session.phase == .working,
                tint: Palette.normal
            )
            timelineRule
            TimelineMetric(
                label: "下班",
                value: Fmt.time(model.session.normalEndedAt),
                isActive: false,
                tint: Palette.normal
            )
            timelineRule
            TimelineMetric(
                label: "加班",
                value: Fmt.time(model.session.overtimeStartedAt),
                isActive: model.session.phase == .overtime,
                tint: Palette.gold
            )
            timelineRule
            TimelineMetric(
                label: "收工",
                value: Fmt.time(model.session.overtimeEndedAt),
                isActive: false,
                tint: Palette.gold
            )
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 6)
        .cardSurface(cornerRadius: 16)
    }

    private var timelineRule: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(width: 0.8, height: 24)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Text("普通 ¥\(Fmt.money(model.settings.normalHourlyRate))/时")
            Text("·")
            Text("加班 ¥\(Fmt.money(model.settings.overtimePerMinuteRate * 60))/时")
            Spacer()
            Button {
                pendingConfirmation = .reset
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("重置本次")
                }
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!model.session.hasRecordedTime)
            .opacity(model.session.hasRecordedTime ? 1 : 0.45)
        }
        .font(.system(size: 9.5, weight: .medium, design: .rounded).monospacedDigit())
        .foregroundStyle(Palette.tertiary)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 13)
    }
}

// MARK: - Components

struct LogoMark: View {
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
            Text("¥")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.heroText)
                .offset(y: -0.5)
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 3, height: 3)
                .offset(x: -8, y: -9)
        }
        .frame(width: 36, height: 36)
        .shadow(color: Palette.normal.opacity(0.22), radius: 7, x: 0, y: 3)
    }
}

struct LiveBadge: View {
    let phase: WorkPhase
    @State private var pulsing = false

    private var color: Color {
        switch phase {
        case .working: return Color(hex: 0x7DE2B1)
        case .overtime: return Color(hex: 0xF5CB7A)
        case .clockedOut, .finished: return Palette.heroText.opacity(0.5)
        case .idle: return Palette.heroText.opacity(0.38)
        }
    }

    private var label: String {
        switch phase {
        case .idle: return "待开始"
        case .working: return "计薪中"
        case .clockedOut: return "已下班"
        case .overtime: return "加班中"
        case .finished: return "已完成"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                if phase.isEarning {
                    Circle()
                        .fill(color.opacity(0.32))
                        .frame(width: 12, height: 12)
                        .scaleEffect(pulsing ? 1.35 : 0.55)
                        .opacity(pulsing ? 0 : 1)
                }
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(0.3)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.09))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7))
        )
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

struct RateMetric: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("¥")
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint.opacity(0.55))
                Text(value)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PunchButton: View {
    enum Style {
        case green
        case gold
        case ink
    }

    let title: String
    let icon: String
    let style: Style
    let isEnabled: Bool
    let action: () -> Void

    @State private var hovering = false

    private var foreground: Color {
        guard isEnabled else { return Palette.tertiary }
        switch style {
        case .green: return Palette.heroText
        case .gold: return Color(hex: 0x2B1A04)
        case .ink: return Palette.buttonInkText
        }
    }

    private var background: AnyShapeStyle {
        guard isEnabled else {
            return AnyShapeStyle(Palette.surfaceMuted.opacity(0.5))
        }
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
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .bold))
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        isEnabled ? Color.white.opacity(0.10) : Palette.line,
                        lineWidth: 0.8
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(hovering && isEnabled ? 0.055 : 0))
            )
            .opacity(isEnabled ? 1 : 0.72)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .onHover { hovering = $0 }
        .help(title)
    }
}

struct TimelineMetric: View {
    let label: String
    let value: String
    let isActive: Bool
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                if isActive {
                    Circle()
                        .fill(tint)
                        .frame(width: 4, height: 4)
                }
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondary)
            }
            Text(value)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(isActive ? tint : Palette.ink)
        }
        .frame(maxWidth: .infinity)
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
