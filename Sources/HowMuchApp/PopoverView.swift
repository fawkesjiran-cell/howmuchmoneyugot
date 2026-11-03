import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var model: AppModel

    @State private var route: Route = .dashboard

    private enum Route {
        case dashboard
        case settings
    }

    var body: some View {
        ZStack {
            AppBackground()

            Group {
                switch route {
                case .dashboard:
                    DashboardView {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
                            route = .settings
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )

                case .settings:
                    SettingsView {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
                            route = .dashboard
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
                }
            }
        }
        .frame(width: 392, height: 608)
        .environment(\.locale, Locale(identifier: "zh_CN"))
    }
}
