import SwiftUI
import Foundation


extension Notification.Name {
    static let rosterReadinessUpdated = Notification.Name("rosterReadinessUpdated")
}


private struct NeonProminentReady: ButtonStyle {
    var tint: Color = Color.blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [tint, tint.opacity(0.9)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(color: tint.opacity(0.5), radius: 20, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private enum ReadyHaptics {
    static func soft()  { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

final class ReadinessViewModel: ObservableObject {
    @Published var training: Double = 0
    @Published var roster: Double = 0
    @Published var discipline: Double = 0
    @Published var vehicles: Double = 0
    @Published var overall: Double = 0

    private let wTraining = 0.30
    private let wRoster   = 0.30
    private let wDisc     = 0.20
    private let wVeh      = 0.20

    init() {
        NotificationCenter.default.addObserver(
            forName: .rosterReadinessUpdated, object: nil, queue: .main
        ) { [weak self] note in
            guard
                let userInfo = note.userInfo,
                let readiness = userInfo["readiness"] as? Double,
                let restPct   = userInfo["restPct"]   as? Double,
                let hoursPct  = userInfo["hoursPct"]  as? Double,
                let nightStd  = userInfo["nightStd"]  as? Double,
                let conflicts = userInfo["conflicts"] as? Int
            else { return }

            self?.computeRoster(
                nightStd: nightStd, restPct: restPct, hoursPct: hoursPct, conflicts: conflicts
            )
           
            print("📡 رُصدت جاهزية المناوبات: \(Int(readiness))% (راحة \(Int(restPct))%، ساعات \(Int(hoursPct))%)")
        }
    }

    func computeTraining(from soldiers: [SoldierResult]) {
        guard !soldiers.isEmpty else { training = 0; recomputeOverall(); return }
        let avg = Double(soldiers.map(\.score).reduce(0, +)) / Double(soldiers.count)
        training = avg.rounded()
        recomputeOverall()
    }

    func computeRoster(nightStd: Double, restPct: Double, hoursPct: Double, conflicts: Int) {
        let fairness = max(0, 100 - min(100, (nightStd / 2.0) * 100))
        let conflictsScore = (conflicts == 0) ? 100.0 : 0.0
        let score = fairness * 0.4 + restPct * 0.3 + hoursPct * 0.2 + conflictsScore * 0.1
        roster = max(0, min(100, score)).rounded()
        recomputeOverall()
    }

    // MARK: Discipline
    func computeDiscipline(eventsCount: Int, totalAssignments: Int) {
        guard totalAssignments > 0 else { discipline = 0; recomputeOverall(); return }
        let per100 = Double(eventsCount) / Double(totalAssignments) * 100.0
        let score = max(0, 100 - min(per100 * 8, 60))
        discipline = score.rounded()
        recomputeOverall()
    }

    func computeVehicles(ready: Int, total: Int) {
        guard total > 0 else { vehicles = 0; recomputeOverall(); return }
        let pct = Double(ready) / Double(total) * 100.0
        vehicles = pct.rounded()
        recomputeOverall()
    }

    private func recomputeOverall() {
        let total = training * wTraining + roster * wRoster + discipline * wDisc + vehicles * wVeh
        overall = max(0, min(100, total)).rounded()
    }

    func color(for value: Double) -> Color {
        if value >= 80 { return .green }
        if value >= 60 { return .yellow }
        return .orange
    }
}


struct ReadinessDashboardView: View {
    @StateObject private var vm = ReadinessViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0E1116), Color(hex: 0x111827), Color(hex: 0x0B1220)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .trailing, spacing: 16) {

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("الجاهزية")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        Text("مؤشرات التدريب والمناوبات والانضباط والمركبات")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    CardBackground {
                        HStack(spacing: 14) {
                            DonutProgress(progress: vm.overall / 100)
                                .frame(width: 88, height: 88)
                                .overlay(Circle().stroke(vm.color(for: vm.overall).opacity(0.25), lineWidth: 3))
                            VStack(alignment: .trailing, spacing: 6) {
                                Text("الجاهزية الإجمالية")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                                Text("\(Int(vm.overall))%")
                                    .font(.system(size: 28, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                Text("تدريب 30٪ • مناوبات 30٪ • انضباط 20٪ • مركبات 20٪")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        readinessCard(title: "جاهزية التدريب",   value: vm.training)
                        readinessCard(title: "جاهزية المناوبات", value: vm.roster)
                        readinessCard(title: "الانضباط",         value: vm.discipline)
                        readinessCard(title: "جاهزية المركبات",  value: vm.vehicles)
                    }

                    VStack(spacing: 12) {
                        Button {
                            vm.computeTraining(from: SampleData.soldiers)
                            ReadyHaptics.soft()
                        } label: {
                            Label("تحديث التدريب", systemImage: "arrow.clockwise.circle.fill")
                                .font(.headline)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(NeonProminentReady(tint: Color(hex: 0x3B82F6)))

                        Button {
                            vm.computeDiscipline(eventsCount: 4, totalAssignments: 120)
                            vm.computeVehicles(ready: 9, total: 10)
                            ReadyHaptics.light()
                        } label: {
                            Label("تحديث الانضباط والمركبات", systemImage: "gearshape.2.fill")
                                .font(.headline)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(NeonProminentReady(tint: Color(hex: 0x22C55E)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            vm.computeTraining(from: SampleData.soldiers)
        }
    }

    @ViewBuilder
    private func readinessCard(title: String, value: Double) -> some View {
        CardBackground {
            VStack(alignment: .trailing, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 10) {
                    DonutProgress(progress: value / 100)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(value))%")
                            .font(.system(size: 22, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        HStack(spacing: 6) {
                            Circle().fill(vm.color(for: value)).frame(width: 8, height: 8)
                            Text(value >= 80 ? "ممتاز" : (value >= 60 ? "جيد" : "يحتاج متابعة"))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}


struct ReadinessDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ReadinessDashboardView()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
