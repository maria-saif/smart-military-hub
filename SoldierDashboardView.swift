import SwiftUI
import UIKit

struct SoldierDashboardView: View {
    @EnvironmentObject var session: SessionViewModel

    // MARK: Layout
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    @State private var appear = false
    @State private var showLogoutConfirm = false
    @State private var isSigningOut = false

    var soldierName: String { session.currentUserName ?? "الجندي" }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView {
                    VStack(spacing: 18) {
                        DashboardHeader(soldierName: soldierName, appLogoView: appLogoView)
                            .padding(.horizontal)

                        DashboardGrid(columns: columns)
                            .padding(.horizontal)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 16)
                            .animation(.spring(response: 0.7, dampingFraction: 0.85), value: appear)

                        Spacer(minLength: 14)
                    }
                    .padding(.top, 18)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLogoutConfirm = true
                    } label: {
                        Label("تسجيل الخروج", systemImage: "rectangle.portrait.and.arrow.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(isSigningOut)
                    .accessibilityLabel("تسجيل الخروج")
                }
            }
            .confirmationDialog("تأكيد تسجيل الخروج",
                                isPresented: $showLogoutConfirm,
                                titleVisibility: .visible) {
                Button("تسجيل الخروج", role: .destructive) {
                    isSigningOut = true
                    session.signOut()
                    isSigningOut = false
                }
                Button("إلغاء", role: .cancel) {}
            }
            .onAppear { appear = true }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [Color.black, Color.green.opacity(0.65)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var appLogoView: some View {
        Group {
            if UIImage(named: "AppLogo") != nil {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "figure.stand")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.green)
            }
        }
    }
}

private struct DashboardHeader: View {
    let soldierName: String
    let appLogoView: AnyView

    init(soldierName: String, appLogoView: some View) {
        self.soldierName = soldierName
        self.appLogoView = AnyView(appLogoView)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 58, height: 58)
                    .overlay(appLogoView)
                    .shadow(color: .green.opacity(0.35), radius: 10, x: 0, y: 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("مرحباً، \(soldierName)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("لوحة الجندي • Smart Military Hub")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer()
        }
    }
}

private struct DashboardGrid: View {
    let columns: [GridItem]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            card(
                title: "لوحة الجندي",
                subtitle: "عرض بياناتي",
                systemImage: "person.text.rectangle",
                tint: .mint
            ) { SoldierProfileView().navigationTitle("لوحة الجندي") }

            card(
                title: "التدريب الذكي",
                subtitle: "دروسي وتماريني",
                systemImage: "book.fill",
                tint: .green
            ) { SoldierTrainingView().navigationTitle("التدريب") }

            card(
                title: "المناوبات",
                subtitle: "جدولي اليومي",
                systemImage: "calendar.badge.clock",
                tint: .blue
            ) { SoldierShiftsScreen().navigationTitle("المناوبات") }

            card(
                title: "التنبيهات",
                subtitle: "إشعارات + أخطاء",
                systemImage: "bell.fill",
                tint: .orange
            ) { SoldierAlertsView().navigationTitle("التنبيهات") }

            card(
                title: "الشات بوت الميداني",
                subtitle: "اسأل • نفّذ أوامر",
                systemImage: "bubble.left.and.bubble.right.fill",
                tint: .teal
            ) { SoldierChatBotView().navigationTitle("الشات بوت") }

            card(
                title: "المكتبة الميدانية",
                subtitle: "ملفات + مستندات",
                systemImage: "folder.fill",
                tint: .purple
            ) { FieldLibraryView().navigationTitle("المكتبة") }

            card(
                title: "المهام اليومية",
                subtitle: "مهامي وحالتها",
                systemImage: "checkmark.square.fill",
                tint: .indigo
            ) { SoldierTasksView().navigationTitle("المهام اليومية") }

            card(
                title: "طلبات الإجازة",
                subtitle: "قدّم وتتبع الطلب",
                systemImage: "airplane.circle.fill",
                tint: .pink
            ) { LeaveRequestsView().navigationTitle("طلبات الإجازة") }

            card(
                title: "الصحة واللياقة",
                subtitle: "مؤشرات وأهداف",
                systemImage: "heart.fill",
                tint: .red
            ) { SoldierHealthView().navigationTitle("الصحة واللياقة") }
        }
    }

    @ViewBuilder
    private func card<V: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder destination: @escaping () -> V
    ) -> some View {
        DashCard(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            tint: tint,
            isWide: false,
            action: {},
            destination: destination
        )
    }
}

#Preview {
    SoldierDashboardView()
        .environmentObject(SessionViewModel.preview)
        .preferredColorScheme(.dark)
}
