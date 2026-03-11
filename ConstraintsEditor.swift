import SwiftUI

struct ConstraintsEditor: View {
    @Binding var constraints: SchedulingConstraints

    @State private var baseline: SchedulingConstraints?
    @State private var showRiskBanner = false
    @State private var showSavedToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.054, green: 0.067, blue: 0.086),
                        Color(red: 0.102, green: 0.137, blue: 0.196)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        maxHoursCard
                        restHoursCard
                        nightBiasCard
                        if showRiskBanner { riskBanner }
                        tipsCard
                        footerButtons
                    }
                    .padding(16)
                }
            }
            .navigationTitle("القيود")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        haptic(.medium)
                        if let baseline { constraints = baseline }
                    } label: {
                        Label("استعادة الافتراضي", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("استعادة الإعدادات الافتراضية")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        haptic(.success)
                        showSavedToast = true
                        // احفظ هنا (UserDefaults/Cloud/Firestore) إن رغبت
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            showSavedToast = false
                        }
                    } label: {
                        Label("حفظ", systemImage: "checkmark.seal.fill")
                    }
                    .tint(Color.green)
                    .accessibilityLabel("حفظ الإعدادات")
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedToast { savedToast }
            }
            .onAppear {
                if baseline == nil { baseline = constraints }
                validate()
            }
            .onChange(of: constraints) { _ in validate() }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}


private extension ConstraintsEditor {
    var headerCard: some View {
        ConstraintsGlassCard {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    Image(systemName: "slider.horizontal.3")
                        .imageScale(.large)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("إدارة القيود")
                        .font(.title3).fontWeight(.semibold)
                    Text("اضبط ساعات العمل، فترات الراحة، وتحيّز الشفت الليلي لضمان توازن الجاهزية مع الرفاه الوظيفي.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    var maxHoursCard: some View {
        ConstraintsGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("أقصى ساعات في الأسبوع")
                        .font(.headline)
                } icon: {
                    Image(systemName: "clock.badge.exclamationmark")
                }

                HStack {
                    Text("من 8 إلى 72 ساعة")
                        .foregroundStyle(.secondary)
                    Spacer()
                    ConstraintsValuePill("\(constraints.maxHoursPerWeek) س/أسبوع")
                }

                // Slider بخطوات 4 ساعات
                Slider(
                    value: Binding(
                        get: { Double(constraints.maxHoursPerWeek) },
                        set: { newVal in
                            constraints.maxHoursPerWeek = Int(newVal).roundedTo(step: 4).clamped(8, 72)
                        }
                    ),
                    in: 8...72,
                    step: 4
                )
                .accessibilityLabel("أقصى ساعات في الأسبوع")

                HStack {
                    Stepper("", value: $constraints.maxHoursPerWeek, in: 8...72, step: 4)
                        .labelsHidden()
                    Spacer()
                    ConstraintsTag(text: recommendationForHours, style: .info)
                }

                Divider().blendMode(.overlay)

                Text("نصيحة: غالبًا ما يكون ٤٨ ساعة/أسبوع توازنًا جيدًا بين التغطية والإنهاك.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var restHoursCard: some View {
        ConstraintsGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("أقل فترة راحة بين الشفتات")
                        .font(.headline)
                } icon: {
                    Image(systemName: "bed.double.fill")
                }

                HStack {
                    Text("من 0 إلى 16 ساعة")
                        .foregroundStyle(.secondary)
                    Spacer()
                    ConstraintsValuePill("\(constraints.minRestHoursBetweenShifts) س")
                }

                Slider(
                    value: Binding(
                        get: { Double(constraints.minRestHoursBetweenShifts) },
                        set: { newVal in
                            constraints.minRestHoursBetweenShifts = Int(newVal).clamped(0, 16)
                        }
                    ),
                    in: 0...16,
                    step: 1
                )
                .accessibilityLabel("أقل فترة راحة")

                Stepper("زيادة/نقصان ساعة",
                        value: $constraints.minRestHoursBetweenShifts,
                        in: 0...16,
                        step: 1)

                if constraints.minRestHoursBetweenShifts < 6 {
                    ConstraintsTag(text: "مخاطرة بالإجهاد", style: .warning)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    ConstraintsTag(text: "مستوى آمن", style: .ok)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                Divider().blendMode(.overlay)

                Text("كلما زادت الراحة، قلّت الأخطاء وتحسّنت الجاهزية على المدى الطويل.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var nightBiasCard: some View {
        ConstraintsGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("تجنّب تحيّز الشفت الليلي")
                        .font(.headline)
                } icon: {
                    Image(systemName: "moon.stars.fill")
                }

                Toggle("توزيع أكثر عدلاً للشفتات الليلية",
                       isOn: $constraints.avoidNightBias.animation(.spring(response: 0.35)))

                if constraints.avoidNightBias {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("مفعّل: سيُراعى تدوير عادل لليالي.")
                        Spacer()
                        ConstraintsTag(text: "موصى به", style: .ok)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("متوقف: قد تحدث انحيازات مزعجة للطاقم.")
                        Spacer()
                        ConstraintsTag(text: "راجع القرار", style: .warning)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    var tipsCard: some View {
        ConstraintsGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("تلميحات سريعة", systemImage: "lightbulb.fill")
                    .font(.headline)
                ConstraintsTipRow(icon: "target", text: "اربط القيود بأهداف الوحدة: التغطية أم الرفاه؟")
                ConstraintsTipRow(icon: "rectangle.3.group.bubble.left", text: "استطلع رأي الفريق دوريًا لضبط الحدود.")
                ConstraintsTipRow(icon: "doc.text.magnifyingglass", text: "هبوط الأداء ⇒ ارفع الراحة وخفّض الساعات.")
            }
        }
    }

    var footerButtons: some View {
        HStack(spacing: 12) {
            Button {
                haptic(.soft)
                if let baseline { constraints = baseline }
            } label: {
                Label("افتراضي", systemImage: "gobackward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ConstraintsPrimaryStyle(tint: Color.gray))

            Button {
                haptic(.success)
                showSavedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    showSavedToast = false
                }
            } label: {
                Label("تطبيق", systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ConstraintsPrimaryStyle(tint: Color.green))
        }
    }

    var riskBanner: some View {
        ConstraintsGlassCard(tint: Color.red.opacity(0.25)) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 4) {
                    Text("تنبيه مخاطر محتمل")
                        .font(.headline)
                    Text("راحة < 6 ساعات مع سقف ساعات مرتفع قد يرفع الإجهاد والأخطاء.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    var savedToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
            Text("تم الحفظ")
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 18)
        .shadow(radius: 8, y: 2)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}


private extension ConstraintsEditor {
    var recommendationForHours: String {
        switch constraints.maxHoursPerWeek {
        case ..<36: return "اقتصادي جدًا"
        case 36...48: return "متوازن"
        case 52...: return "مرتفع"
        default: return "مناسب"
        }
    }

    func validate() {
        let risky = constraints.minRestHoursBetweenShifts < 6 && constraints.maxHoursPerWeek >= 48
        withAnimation(.spring(response: 0.35)) {
            showRiskBanner = risky
        }
        if risky { haptic(.rigid) }
    }

    enum HapticStyle { case success, warning, error, soft, light, medium, rigid }

    func haptic(_ style: HapticStyle) {
        #if canImport(UIKit)
        switch style {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        #endif
    }
}


private struct ConstraintsGlassCard<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(
            (tint ?? Color.white.opacity(0.08))
                .blendMode(.overlay)
                .overlay(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
        .shadow(color: Color.black.opacity(0.25), radius: 18, y: 8)
    }
}

private struct ConstraintsValuePill: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.callout.monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct ConstraintsTag: View {
    enum Style { case ok, warning, info }
    let text: String
    let style: Style

    var body: some View {
        let color: Color = {
            switch style {
            case .ok: return Color.green
            case .warning: return Color.orange
            case .info: return Color.blue
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.caption).fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

private struct ConstraintsTipRow: View {
    var icon: String
    var text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.secondary)
        .font(.subheadline)
    }
}

private struct ConstraintsPrimaryStyle: ButtonStyle {
    var tint: Color = .accentColor
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.7 : 0.9))
            )
            .foregroundStyle(Color.white)
            .shadow(radius: configuration.isPressed ? 2 : 8, y: configuration.isPressed ? 1 : 4)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}


private extension Int {
    func clamped(_ lower: Int, _ upper: Int) -> Int { Swift.min(Swift.max(self, lower), upper) }
    func roundedTo(step: Int) -> Int {
        guard step > 0 else { return self }
        let r = Double(self) / Double(step)
        return Int((r.rounded()) * Double(step))
    }
}


struct ConstraintsEditor_Previews: PreviewProvider {
    struct Wrapper: View {
        @State var constraints = SchedulingConstraints(
            maxHoursPerWeek: 48,
            minRestHoursBetweenShifts: 8,
            avoidNightBias: true
        )
        var body: some View {
            ConstraintsEditor(constraints: $constraints)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
    static var previews: some View {
        Group {
            Wrapper()
                .previewDisplayName("Arabic RTL - Dark")
                .preferredColorScheme(.dark)

            Wrapper()
                .previewDisplayName("Arabic RTL - Light")
                .preferredColorScheme(.light)
        }
    }
}
