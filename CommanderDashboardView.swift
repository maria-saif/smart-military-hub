import SwiftUI
import LocalAuthentication
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore

struct CommanderDashboardView: View {
    @EnvironmentObject var session: SessionViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    @State private var appear = false
    @Namespace private var ns

    @State private var showLogoutConfirm = false
    @State private var isSigningOut = false

    @State private var activeSoldiersCount: Int = 0
    private let counterService = ActiveSoldiersCounterService()

    var commanderName: String { session.currentUserName ?? "القائد" }

    var body: some View {
        NavigationStack {
            ZStack {
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(hex: 0x0E1116),
                        Color(hex: 0x12202E),
                        Color(hex: 0x0E1116)
                    ]),
                    center: .topLeading
                )
                .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color(hex: 0x3AD29F).opacity(0.18),
                        Color(hex: 0x7AA5FF).opacity(0.14),
                        .clear
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .blendMode(.plusLighter)
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 22) {

                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle().stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.5), .white.opacity(0.08)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                    )
                                    .shadow(color: .white.opacity(0.08), radius: 12, y: 6)
                                    .frame(width: 62, height: 62)
                                    .overlay(
                                        Image(systemName: "shield.lefthalf.filled")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color(hex: 0x3AD29F), Color(hex: 0x2ED6FF)],
                                                    startPoint: .top, endPoint: .bottom
                                                )
                                            )
                                    )
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("مرحباً، \(commanderName)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .matchedGeometryEffect(id: "title", in: ns)

                                Text("Smart Military Hub • لوحة القائد")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.70))
                            }

                            Spacer(minLength: 8)

                            ReadinessRing(progress: 0.78)
                                .frame(width: 58, height: 58)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)

                        LazyVGrid(columns: columns, spacing: 16) {
                            CardNav(
                                title: "التدريب",
                                subtitle: "نتائج + أخطاء",
                                systemIcon: "book.fill"
                            ) {
                                CommanderTrainingView()
                            }

                            CardNav(
                                title: "المناوبات",
                                subtitle: "توليد + PDF",
                                systemIcon: "calendar.badge.clock"
                            ) {
                                CommanderShiftsView()
                            }

                            NavigationLink {
                                ActiveSoldiersView(leaderUID: session.currentUserUID ?? "")
                                    .navigationTitle("الجنود النشطون")
                                    .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                DashCardTile(
                                    title: "الجنود النشطون",
                                    subtitle: "\(activeSoldiersCount) مستخدم",
                                    systemIcon: "person.3.fill"
                                )
                            }
                            .buttonStyle(.plain)


                            CardNav(
                                title: "إجراءات سريعة",
                                subtitle: "SOP + قوائم",
                                systemIcon: "checklist"
                            ) {
                                SOPListView()
                            }

                            CardNav(
                                title: "الجاهزية",
                                subtitle: "مؤشرات سريعة",
                                systemIcon: "chart.bar.doc.horizontal.fill"
                            ) {
                                ReadinessDashboardView()
                                    .navigationTitle("الجاهزية")
                                    .navigationBarTitleDisplayMode(.inline)
                            }

                            CardNav(
                                title: "التقارير الذكية",
                                subtitle: "PDF أسبوعي",
                                systemIcon: "doc.text.fill"
                            ) {
                                ReportsScreen()
                                    .navigationTitle("التقارير")
                                    .navigationBarTitleDisplayMode(.inline)
                            }

                            CardNav(
                                title: "وضع الطوارئ",
                                subtitle: "جدول مكثّف سريع",
                                systemIcon: "exclamationmark.triangle.fill"
                            ) {
                                EmergencyModeViewV3()
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 18)
                        .animation(.spring(response: 0.65, dampingFraction: 0.86), value: appear)

                        Spacer(minLength: 10)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showLogoutConfirm = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 17, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.12), lineWidth: 1)
                            )
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
                    signOut()
                    isSigningOut = false
                }
                Button("إلغاء", role: .cancel) {}
            }
            .onAppear {
                appear = true

                if session.currentUserName == nil, let sid = session.currentServiceId {
                    do {
                        if let user = try DatabaseManager.shared.getUserByServiceId(sid) {
                            session.currentUserName = user.name
                        }
                    } catch {
                        print("DB fetch error:", error.localizedDescription)
                    }
                }

                if FirebaseApp.app() != nil,
                   let leaderUID = session.currentUserUID,
                   let authUID = Auth.auth().currentUser?.uid,
                   leaderUID == authUID {
                    counterService.startCount(forLeader: leaderUID) { count in
                        self.activeSoldiersCount = count
                    }
                } else {
                    activeSoldiersCount = 0
                }
            }
            .onDisappear { counterService.stop() }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    @MainActor
    private func signOut() {
        session.signOut()
    }
}

struct ReadinessRing: View {
    var progress: CGFloat // 0...1
    @State private var rotate = false

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: 0x3AD29F), Color(hex: 0x7AA5FF), Color(hex: 0x3AD29F)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(.linear(duration: 3.5).repeatForever(autoreverses: false), value: rotate)

            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("جاهزية")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .onAppear { rotate = true }
        .padding(2)
        .background(
            Circle().fill(.ultraThinMaterial)
                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
    }
}

final class ActiveSoldiersCounterService {
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func startCount(forLeader leaderUID: String, onChange: @escaping (Int) -> Void) {
        stop()
        guard FirebaseApp.app() != nil,
              let uid = Auth.auth().currentUser?.uid,
              uid == leaderUID else {
            onChange(0); return
        }
        listener = db.collection("soldiers")
            .document(leaderUID)
            .collection("soldiers")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("ActiveSoldiers count error:", error)
                    onChange(0)
                    return
                }
                onChange(snapshot?.documents.count ?? 0)
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

#Preview {
    NavigationStack {
        CommanderDashboardView()
            .environmentObject(SessionViewModel.preview)
    }
    .preferredColorScheme(.dark)
}
