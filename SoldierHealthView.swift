import SwiftUI
import UIKit
#if canImport(Charts)
import Charts
#endif

struct SoldierHealthView: View {
    @State private var stepsToday: Int = 7540
    @State private var heartRateResting: Int = 64
    @State private var heartRateCurrent: Int = 78
    @State private var vo2max: Int = 42
    @State private var caloriesToday: Int = 520
    @State private var hydrationPct: Double = 0.62
    @State private var sleepHours: Double = 6.8
    @State private var hrv: Int = 52

    @State private var stepsGoal: Int = 10_000
    @State private var caloriesGoal: Int = 700
    @State private var hydrationGoalPct: Double = 0.8
    @State private var strengthPerWeekGoal: Int = 3
    @State private var completedStrengthThisWeek: Int = 2

    @State private var weekData: HealthDayPoint.Week = HealthDayPoint.sampleWeek()
    @State private var isSyncing: Bool = false

    var body: some View {
        ZStack {
            AngularGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.18, blue: 0.12),
                    Color(red: 0.10, green: 0.30, blue: 0.20),
                    Color.black
                ]),
                center: .topLeading
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    ringsRow
                    metricsGrid
                    weeklySection
                    goalsSection
                    actionsRow
                    Spacer(minLength: 18)
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("الصحة واللياقة")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { syncNow() } label: {
                    Label("مزامنة", systemImage: isSyncing ? "arrow.triangle.2.circlepath.circle.fill"
                                                           : "arrow.triangle.2.circlepath.circle")
                        .symbolEffect(.rotate, value: isSyncing)
                }
                .accessibilityLabel("مزامنة البيانات")
                .disabled(isSyncing)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 54, height: 54)
                Image(systemName: "heart.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.red.opacity(0.9))
                    .shadow(color: Color.red.opacity(0.4), radius: 10, x: 0, y: 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("الصحة واللياقة")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("مؤشرات اليوم • Smart Military Hub")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("الصحة واللياقة. مؤشرات اليوم.")
    }

    private var ringsRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            HealthGlassCard {
                HealthRingStat(
                    title: "الخطوات",
                    value: Double(stepsToday),
                    target: Double(stepsGoal),
                    unit: "",
                    symbol: "figure.walk",
                    tint: .mint
                )
            }
            HealthGlassCard {
                HealthRingStat(
                    title: "السعرات",
                    value: Double(caloriesToday),
                    target: Double(caloriesGoal),
                    unit: "kcal",
                    symbol: "flame.fill",
                    tint: .orange
                )
            }
            HealthGlassCard {
                HealthRingStat(
                    title: "الترطيب",
                    value: hydrationPct,
                    target: 1.0,
                    unit: "%",
                    symbol: "drop.fill",
                    tint: .cyan,
                    displayAsPercent: true
                )
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {

            HealthMetricCard(
                title: "نبض حالي",
                subtitle: "bpm",
                value: "\(heartRateCurrent)",
                systemImage: "waveform.path.ecg",
                tint: Color.red,
                footnote: "الراحة: \(heartRateResting) bpm"
            )

            HealthMetricCard(
                title: "VO₂ Max",
                subtitle: "تقديري",
                value: "\(vo2max)",
                systemImage: "lungs.fill",
                tint: Color.green,
                footnote: "أعلى أفضل"
            )

            HealthMetricCard(
                title: "النوم",
                subtitle: "ساعات",
                value: String(format: "%.1f", sleepHours),
                systemImage: "bed.double.fill",
                tint: Color.indigo,
                footnote: sleepHours >= 7.0 ? "ممتاز" : "حسّنه قليلاً"
            )

            HealthMetricCard(
                title: "HRV",
                subtitle: "ms",
                value: "\(hrv)",
                systemImage: "bolt.heart.fill",
                tint: Color.purple,
                footnote: "تغير نبضي"
            )
        }
    }

    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "الأسبوع", system: "calendar")

            HealthGlassCard(padding: 8) {
                #if canImport(Charts)
                if #available(iOS 16.0, *) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("الخطوات خلال ٧ أيام")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 6)

                        Chart {
                            ForEach(weekData) { point in
                                LineMark(
                                    x: .value("اليوم", point.dayShortArabic),
                                    y: .value("خطوات", point.steps)
                                )
                                AreaMark(
                                    x: .value("اليوم", point.dayShortArabic),
                                    y: .value("خطوات", point.steps)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(LinearGradient(
                                    colors: [Color.mint.opacity(0.6), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                            }
                        }
                        .frame(height: 170)

                        HStack {
                            statPill(icon: "figure.walk", label: "اليوم", value: "\(stepsToday)")
                            Spacer()
                            let avg = Int(weekData.map{$0.steps}.reduce(0,+) / max(1, weekData.count))
                            statPill(icon: "chart.line.uptrend.xyaxis", label: "المتوسط", value: "\(avg)")
                        }
                    }
                } else {
                    fallbackWeeklyList
                }
                #else
                fallbackWeeklyList
                #endif
            }
        }
    }

    private var fallbackWeeklyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("الخطوات خلال ٧ أيام")
                .font(.headline)
                .foregroundColor(.white)
            ForEach(weekData) { p in
                HStack {
                    Text(p.dayShortArabic)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    ProgressView(value: min(Double(p.steps) / Double(stepsGoal), 1.0))
                        .tint(.mint)
                        .frame(width: 140)
                    Text("\(p.steps)")
                        .foregroundColor(.white.opacity(0.85))
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
        .padding(8)
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "الأهداف", system: "target")

            VStack(spacing: 12) {
                HealthGoalRow(
                    title: "هدف الخطوات",
                    valueText: "\(stepsToday) / \(stepsGoal)",
                    progress: progress(current: stepsToday, target: stepsGoal),
                    tint: .mint,
                    icon: "figure.walk"
                )
                HealthGoalRow(
                    title: "السعرات المحروقة",
                    valueText: "\(caloriesToday) / \(caloriesGoal) kcal",
                    progress: progress(current: caloriesToday, target: caloriesGoal),
                    tint: .orange,
                    icon: "flame.fill"
                )
                HealthGoalRow(
                    title: "الترطيب",
                    valueText: "\(Int(hydrationPct * 100))٪ / \(Int(hydrationGoalPct * 100))٪",
                    progress: min(hydrationPct / hydrationGoalPct, 1.0),
                    tint: .cyan,
                    icon: "drop.fill"
                )
                HealthGoalRow(
                    title: "تمارين القوة (أسبوعي)",
                    valueText: "\(completedStrengthThisWeek) / \(strengthPerWeekGoal)",
                    progress: progress(current: completedStrengthThisWeek, target: strengthPerWeekGoal),
                    tint: .indigo,
                    icon: "dumbbell.fill"
                )
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            Button { simpleHaptic(.success) } label: {
                HealthActionButtonLabel(title: "ابدأ تمرين", system: "figure.run.circle.fill")
            }
            Button { syncNow() } label: {
                HealthActionButtonLabel(title: isSyncing ? "جاري المزامنة..." : "مزامنة",
                                        system: "arrow.triangle.2.circlepath.circle.fill")
            }
            .disabled(isSyncing)
            .opacity(isSyncing ? 0.8 : 1)
        }
    }

    private func progress(current: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    private func syncNow() {
        guard !isSyncing else { return }
        isSyncing = true
        simpleHaptic(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let extra = Int.random(in: 50...250)
            stepsToday = min(stepsToday + extra, stepsGoal + 1500)
            caloriesToday = min(caloriesToday + Int.random(in: 20...60), caloriesGoal + 200)
            heartRateCurrent = max(58, min(110, heartRateCurrent + Int.random(in: -5...5)))
            hydrationPct = min(1.0, hydrationPct + Double.random(in: 0.0...0.05))
            sleepHours = max(5.0, min(8.5, sleepHours + Double.random(in: -0.2...0.2)))
            hrv = max(35, min(85, hrv + Int.random(in: -3...3)))
            weekData = HealthDayPoint.shiftRandomized(from: weekData)
            isSyncing = false
        }
    }

    private func sectionHeader(title: String, system: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: system).foregroundColor(.white.opacity(0.9))
            Text(title).foregroundColor(.white).font(.headline)
            Spacer()
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private func statPill(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(label).font(.footnote)
            Text(value)
                .font(.footnote.monospacedDigit())
                .foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .foregroundColor(.white.opacity(0.85))
    }

    private func simpleHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(type)
    }
}

#Preview {
    NavigationStack {
        SoldierHealthView().preferredColorScheme(.dark)
    }
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "ar"))
}


private struct HealthGlassCard<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        VStack { content }
            .frame(maxWidth: .infinity)
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            }
    }
}

private struct HealthProgressRing: View {
    let progress: Double, lineWidth: CGFloat, size: CGFloat, tint: Color
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
            Text("\(Int(progress * 100))٪")
                .font(.footnote.monospacedDigit())
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: size, height: size)
    }
}

private struct HealthRingStat: View {
    let title: String
    let value: Double
    let target: Double
    let unit: String
    let symbol: String
    let tint: Color
    var displayAsPercent: Bool = false

    var pct: Double { target > 0 ? min(value / target, 1.0) : 0 }

    private var percentText: String {
        let n = Int(value * 100)
        return "\(n)\u{066A}"
    }

    private var displayValue: String {
        if displayAsPercent { return percentText }
        if unit.isEmpty { return "\(Int(value))" }
        return "\(Int(value)) \(unit)"
    }

    var body: some View {
        HStack(spacing: 12) {
            HealthProgressRing(progress: pct, lineWidth: 9, size: 70, tint: tint)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: symbol).foregroundColor(tint)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(displayValue)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()

                if !displayAsPercent {
                    Text("الهدف: \(Int(target))")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
    }
}

private struct HealthMetricCard: View {
    let title: String
    let subtitle: String
    let value: String
    let systemImage: String
    let tint: Color
    var footnote: String? = nil

    var body: some View {
        HealthGlassCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: systemImage)
                        .foregroundColor(tint)
                        .font(.system(size: 20, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundColor(.white).font(.headline)
                    Text(subtitle).foregroundColor(.white.opacity(0.7)).font(.caption)
                }
                Spacer()
                Text(value).font(.title3.bold()).foregroundColor(.white)
            }
            if let foot = footnote {
                Divider().background(.white.opacity(0.08))
                HStack {
                    Image(systemName: "info.circle")
                    Text(foot)
                }
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

private struct HealthGoalRow: View {
    let title: String
    let valueText: String
    let progress: Double
    let tint: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(tint)
                    .frame(width: 20)
                Text(title)
                    .foregroundColor(.white)
                    .font(.subheadline.bold())
                Spacer()
                Text(valueText)
                    .foregroundColor(.white)
                    .font(.subheadline.monospacedDigit())
            }
            ProgressView(value: progress)
                .tint(tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). التقدم \(Int(progress * 100))٪. \(valueText)")
    }
}

private struct HealthActionButtonLabel: View {
    let title: String
    let system: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: system)
            Text(title).font(.headline)
        }
        .foregroundColor(.black)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color.white, Color.white.opacity(0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 6)
    }
}

private struct HealthDayPoint: Identifiable {
    typealias Week = [HealthDayPoint]
    let id = UUID()
    let day: Date
    let steps: Int
    let avgHR: Int

    var dayShortArabic: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ar")
        fmt.dateFormat = "EEE"
        return fmt.string(from: day)
    }

    static func sampleWeek() -> Week {
        let cal = Calendar.current
        let today = Date()
        return (0..<7).reversed().map { i in
            let d = cal.date(byAdding: .day, value: -i, to: today)!
            return HealthDayPoint(day: d,
                                  steps: Int.random(in: 5200...11500),
                                  avgHR: Int.random(in: 62...86))
        }
    }

    static func shiftRandomized(from current: Week) -> Week {
        guard let last = current.last?.day else { return sampleWeek() }
        let cal = Calendar.current
        let next = cal.date(byAdding: .day, value: 1, to: last) ?? Date()
        var arr = Array(current.dropFirst())
        arr.append(HealthDayPoint(day: next,
                                  steps: Int.random(in: 5200...11500),
                                  avgHR: Int.random(in: 62...86)))
        return arr
    }
}
