import SwiftUI
import UIKit

struct RoleGateView: View {
    @EnvironmentObject var session: SessionViewModel

    enum SheetRoute: Int, Identifiable {
        case commander, soldier
        var id: Int { rawValue }
    }

    @State private var activeSheet: SheetRoute? = nil
    @State private var shine = false

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackdrop()
                GrainOverlay()

                VStack(spacing: 22) {
                    Spacer(minLength: 24)
                    ShieldLogo()

                    Text("تسجيل الدخول")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, 4)

                    HStack(spacing: 14) {
                        RoleButton(
                            title: "قائد",
                            systemImage: "shield.fill",
                            subtitle: "إدارة الجداول والتدريب",
                            tint: .white
                        ) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            activeSheet = .commander
                        }

                        RoleButton(
                            title: "جندي",
                            systemImage: "figure.stand",
                            subtitle: "تنفيذ التدريب وجدولي",
                            tint: .white
                        ) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            activeSheet = .soldier
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    Text("© 2025 Smart Military Hub – جميع الحقوق محفوظة")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 10)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("العربية / English")
                        .font(.caption).bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.16), in: Capsule())
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: false)) {
                    shine.toggle()
                }
            }
        }
        .sheet(item: $activeSheet) { route in
            switch route {
            case .commander:
                CommanderAuthView().environmentObject(session)
            case .soldier:
                SoldierAuthView().environmentObject(session)
            }
        }
    }
}

private struct RoleButton: View {
    let title: String
    let systemImage: String
    let subtitle: String
    let tint: Color
    var action: () -> Void

    @State private var isPressed = false
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isPressed = false }
            action()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 6)

                VStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(title).font(.headline).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.9))
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 10)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.0), .white.opacity(0.22), .white.opacity(0.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(15))
                    .offset(x: shimmerPhase * 160)
                    .onAppear {
                        withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                            shimmerPhase = 1.4
                        }
                    }
                    .allowsHitTesting(false)
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private struct ShieldLogo: View {
    @State private var scale: CGFloat = 0.96
    var body: some View {
        ZStack {
            RoundedShield()
                .stroke(.white.opacity(0.16), lineWidth: 1.2)
                .background(RoundedShield().fill(.white.opacity(0.06)))
                .frame(width: 112, height: 128)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 6)

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(radius: 8)
        }
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                scale = 1.02
            }
        }
    }
}

private struct RoundedShield: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let top = CGPoint(x: w*0.5, y: 0)
        let leftTop = CGPoint(x: 0, y: h*0.2)
        let rightTop = CGPoint(x: w, y: h*0.2)
        let leftBottom = CGPoint(x: w*0.2, y: h*0.95)
        let rightBottom = CGPoint(x: w*0.8, y: h*0.95)

        p.move(to: top)
        p.addQuadCurve(to: leftTop, control: CGPoint(x: w*0.15, y: h*0.02))
        p.addQuadCurve(to: leftBottom, control: CGPoint(x: w*0.02, y: h*0.55))
        p.addQuadCurve(to: rightBottom, control: CGPoint(x: w*0.5, y: h*1.02))
        p.addQuadCurve(to: rightTop, control: CGPoint(x: w*0.98, y: h*0.55))
        p.addQuadCurve(to: top, control: CGPoint(x: w*0.85, y: h*0.02))
        return p
    }
}

private struct AnimatedBackdrop: View {
    @State private var angle: CGFloat = 0
    var body: some View {
        AngularGradient(
            gradient: Gradient(colors: [Color.black, Color.green.opacity(0.6), Color.black]),
            center: .topLeading,
            angle: .degrees(Double(angle))
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }
}

private struct GrainOverlay: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.white.opacity(0.05), .clear],
                                 startPoint: .top, endPoint: .bottom))
            .blendMode(.overlay)
            .overlay(
                Canvas { ctx, size in
                    for _ in 0..<2500 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let op = Double.random(in: 0.02...0.05)
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                                 with: .color(.white.opacity(op)))
                    }
                }
                .opacity(0.18)
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
