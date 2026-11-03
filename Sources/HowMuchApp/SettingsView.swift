import HowMuchCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    let close: () -> Void

    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    incomeSection
                    rateSection
                    dataSection
                    privacyNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }
        }
        .alert("重置本次计薪？", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                model.resetSession()
            }
        } message: {
            Text("当前累计的 ¥\(Fmt.money(model.snapshot.total)) 将清零，且无法恢复。")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: close) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Palette.surface)
                            .overlay(Circle().strokeBorder(Palette.line, lineWidth: 0.8))
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
            .help("返回")

            VStack(alignment: .leading, spacing: 2) {
                Text("收入与工时")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("修改后立即生效")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondary)
            }

            Spacer()

            Button("完成", action: close)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.normal)
                .buttonStyle(.plain)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Palette.normalSoft)
                )
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Income

    private var incomeSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SmallCapsLabel(text: "收入输入")

            VStack(spacing: 0) {
                SettingNumberRow(
                    icon: "banknote.fill",
                    title: "普通月薪",
                    caption: "税前或到手均可",
                    tint: Palette.normal,
                    value: settingBinding(\.monthlySalary),
                    suffix: "元/月"
                )

                rowDivider

                SettingNumberRow(
                    icon: "calendar",
                    title: "每月工作日",
                    caption: "用于换算普通时薪",
                    tint: Palette.normal,
                    value: settingBinding(\.workDaysPerMonth),
                    suffix: "天"
                )

                rowDivider

                SettingNumberRow(
                    icon: "clock.fill",
                    title: "每日工时",
                    caption: "正常工作的时长",
                    tint: Palette.normal,
                    value: settingBinding(\.hoursPerDay),
                    suffix: "小时"
                )

                rowDivider

                SettingNumberRow(
                    icon: "bolt.fill",
                    title: "加班时薪",
                    caption: "可独立于普通时薪",
                    tint: Palette.gold,
                    value: settingBinding(\.overtimeHourlyRate),
                    suffix: "元/时"
                )

                HStack {
                    if !model.settings.isValid {
                        Label("月薪与工时需大于 0", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.danger)
                    }
                    Spacer()
                    Button {
                        model.useSuggestedOvertimeRate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8.5, weight: .bold))
                            Text("按 1.5× 填入 ¥\(Fmt.money(model.settings.suggestedOvertimeHourlyRate))")
                        }
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.goldDeep)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.settings.isValid)
                }
                .padding(.top, 8)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 4)
            .cardSurface(cornerRadius: 17)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 0.8)
            .padding(.leading, 40)
    }

    // MARK: - Rates

    private var rateSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SmallCapsLabel(text: "换算结果")

            VStack(spacing: 11) {
                HStack(spacing: 0) {
                    RateMetric(
                        label: "每秒",
                        value: Fmt.moneyPrecise(model.settings.normalPerSecondRate),
                        tint: Palette.ink
                    )
                    Rectangle()
                        .fill(Palette.line)
                        .frame(width: 0.8, height: 26)
                        .padding(.horizontal, 9)
                    RateMetric(
                        label: "每分",
                        value: Fmt.money(model.settings.normalPerMinuteRate),
                        tint: Palette.ink
                    )
                    Rectangle()
                        .fill(Palette.line)
                        .frame(width: 0.8, height: 26)
                        .padding(.horizontal, 9)
                    RateMetric(
                        label: "每小时",
                        value: Fmt.money(model.settings.normalHourlyRate),
                        tint: Palette.ink
                    )
                }

                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 0.8)

                HStack(spacing: 8) {
                    SummaryStat(label: "普通时薪", value: "¥\(Fmt.money(model.settings.normalHourlyRate))")
                    Spacer(minLength: 0)
                    SummaryStat(label: "加班时薪", value: "¥\(Fmt.money(model.settings.overtimePerMinuteRate * 60))")
                    Spacer(minLength: 0)
                    SummaryStat(label: "日薪目标", value: "¥\(Fmt.money(model.settings.dailyPay))")
                }

                Text("按每月 \(Fmt.count(model.settings.workDaysPerMonth)) 天、每天 \(Fmt.count(model.settings.hoursPerDay)) 小时换算")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .cardSurface(cornerRadius: 17)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.normalSoft)
                    .frame(width: 34, height: 34)
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.normal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("本次累计")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondary)
                Text("¥\(Fmt.money(model.snapshot.total))")
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.ink)
            }

            Spacer()

            Button {
                showResetAlert = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9, weight: .bold))
                    Text("重置")
                }
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(model.session.hasRecordedTime ? Palette.danger : Palette.tertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(model.session.hasRecordedTime ? Palette.danger.opacity(0.09) : Palette.surfaceMuted)
                )
            }
            .buttonStyle(.plain)
            .disabled(!model.session.hasRecordedTime)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .cardSurface(cornerRadius: 17)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 8.5, weight: .semibold))
                .padding(.top, 1.5)
            Text("计时状态与收入设置只保存在这台 Mac 上；关闭应用后再次打开，会接着上次的状态继续计时。")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .lineSpacing(1.5)
        }
        .foregroundStyle(Palette.tertiary)
        .padding(.horizontal, 2)
    }

    // MARK: - Helpers

    private func settingBinding(_ keyPath: WritableKeyPath<PaySettings, Double>) -> Binding<Double> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in
                guard newValue.isFinite else { return }
                model.settings[keyPath: keyPath] = max(0, newValue)
            }
        )
    }
}

// MARK: - Components

struct SettingNumberRow: View {
    let icon: String
    let title: String
    let caption: String
    let tint: Color
    @Binding var value: Double
    let suffix: String

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.10))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(caption)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.tertiary)
            }

            Spacer(minLength: 6)

            HStack(spacing: 3) {
                TextField(
                    "0",
                    value: $value,
                    format: .number.precision(.fractionLength(0...2))
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .focused($focused)
                .frame(width: 74)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(focused ? Palette.surfaceStrong : Palette.surfaceMuted)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(focused ? tint.opacity(0.65) : Palette.line, lineWidth: 0.8)
                )

                Text(suffix)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 31, alignment: .leading)
            }
        }
        .frame(height: 45)
        .contentShape(Rectangle())
        .onTapGesture {
            focused = true
        }
    }
}

struct SummaryStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.tertiary)
            Text(value)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}
