import SwiftUI

@MainActor
struct PirateTheme {
    private static var isEnabled: Bool {
        AppSettings.shared.pirateThemeEnabled
    }

    // MARK: - Colors

    static var accentColor: Color {
        isEnabled
            ? Color(red: 0xCC/255, green: 0x88/255, blue: 0x03/255)
            : Color(red: 0x90/255, green: 0xCA/255, blue: 0xF9/255)
    }

    static var iconBgColor: Color {
        isEnabled
            ? Color(red: 0x3D/255, green: 0x2E/255, blue: 0x14/255)
            : Color(red: 0x2A/255, green: 0x2A/255, blue: 0x2A/255)
    }

    static var cardBgColor: Color {
        isEnabled
            ? Color(red: 0.1, green: 0.07, blue: 0.04)
            : Color(red: 0x1E/255, green: 0x1E/255, blue: 0x1E/255)
    }

    // MARK: - Fonts

    static func font(size: CGFloat) -> Font {
        isEnabled
            ? .custom("PirataOne-Regular", size: size)
            : .system(size: size)
    }

    static func uiFont(size: CGFloat) -> UIFont {
        isEnabled
            ? UIFont(name: "PirataOne-Regular", size: size) ?? .systemFont(ofSize: size)
            : .systemFont(ofSize: size)
    }

    // MARK: - Gradients / Backgrounds

    static var cardGradient: LinearGradient {
        isEnabled
            ? LinearGradient(
                colors: [Color(red: 0.16, green: 0.12, blue: 0.08), Color(red: 0.1, green: 0.07, blue: 0.04)],
                startPoint: .leading, endPoint: .trailing
              )
            : LinearGradient(
                colors: [Color(red: 0x1E/255, green: 0x1E/255, blue: 0x1E/255)],
                startPoint: .leading, endPoint: .trailing
              )
    }

    static var cardFill: some ShapeStyle {
        isEnabled
            ? AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.16, green: 0.12, blue: 0.08), Color(red: 0.1, green: 0.07, blue: 0.04)],
                startPoint: .leading, endPoint: .trailing
              ))
            : AnyShapeStyle(Color(red: 0x1E/255, green: 0x1E/255, blue: 0x1E/255))
    }
}

struct PirateCardTexture: View {
    let intensity: Double

    init(intensity: Double = 0.07) {
        self.intensity = intensity
    }

    var body: some View {
        Canvas { context, size in
            let ink = PirateTheme.accentColor.opacity(intensity)
            let faintInk = PirateTheme.accentColor.opacity(intensity * 0.55)

            var chartLines = Path()
            var offset = -size.height
            while offset < size.width {
                chartLines.move(to: CGPoint(x: offset, y: 0))
                chartLines.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                offset += 30
            }
            context.stroke(chartLines, with: .color(faintInk), lineWidth: 0.6)

            let compassCenter = CGPoint(
                x: size.width * 0.82,
                y: size.height * 0.24
            )
            let compassRadius = max(18, min(size.width, size.height) * 0.2)
            var compass = Path()
            compass.addEllipse(
                in: CGRect(
                    x: compassCenter.x - compassRadius,
                    y: compassCenter.y - compassRadius,
                    width: compassRadius * 2,
                    height: compassRadius * 2
                )
            )
            compass.addEllipse(
                in: CGRect(
                    x: compassCenter.x - compassRadius * 0.38,
                    y: compassCenter.y - compassRadius * 0.38,
                    width: compassRadius * 0.76,
                    height: compassRadius * 0.76
                )
            )

            for point in 0..<8 {
                let angle = CGFloat(point) * .pi / 4
                let innerRadius = compassRadius * 0.22
                compass.move(
                    to: CGPoint(
                        x: compassCenter.x + cos(angle) * innerRadius,
                        y: compassCenter.y + sin(angle) * innerRadius
                    )
                )
                compass.addLine(
                    to: CGPoint(
                        x: compassCenter.x + cos(angle) * compassRadius,
                        y: compassCenter.y + sin(angle) * compassRadius
                    )
                )
            }
            context.stroke(compass, with: .color(ink), lineWidth: 0.8)

            var route = Path()
            route.move(to: CGPoint(x: size.width * 0.05, y: size.height * 0.78))
            route.addCurve(
                to: CGPoint(x: size.width * 0.72, y: size.height * 0.62),
                control1: CGPoint(x: size.width * 0.28, y: size.height * 0.5),
                control2: CGPoint(x: size.width * 0.5, y: size.height * 0.9)
            )
            context.stroke(
                route,
                with: .color(ink),
                style: StrokeStyle(lineWidth: 0.9, dash: [3, 5])
            )

            let marker = CGPoint(x: size.width * 0.72, y: size.height * 0.62)
            let markerSize: CGFloat = 4
            var destination = Path()
            destination.move(
                to: CGPoint(x: marker.x - markerSize, y: marker.y - markerSize)
            )
            destination.addLine(
                to: CGPoint(x: marker.x + markerSize, y: marker.y + markerSize)
            )
            destination.move(
                to: CGPoint(x: marker.x + markerSize, y: marker.y - markerSize)
            )
            destination.addLine(
                to: CGPoint(x: marker.x - markerSize, y: marker.y + markerSize)
            )
            context.stroke(destination, with: .color(ink), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PirateScreenBackground: View {
    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    PirateTheme.accentColor.opacity(0.09),
                    .clear,
                ],
                center: .top,
                startRadius: 20,
                endRadius: 560
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.08, green: 0.045, blue: 0.015).opacity(0.22),
                    Color.black.opacity(0.3),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct PiratePageHeader: View {
    let title: String
    let icon: String
    let subtitle: String?

    init(title: String, icon: String, subtitle: String? = nil) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                headerLine
                Text(title)
                    .font(PirateTheme.font(size: 34))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                headerLine
                    .scaleEffect(x: -1)
            }

            HStack(spacing: 7) {
                Rectangle()
                    .fill(PirateTheme.accentColor.opacity(0.4))
                    .frame(width: 38, height: 1)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(PirateTheme.accentColor)
                Rectangle()
                    .fill(PirateTheme.accentColor.opacity(0.4))
                    .frame(width: 38, height: 1)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.46))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, subtitle == nil ? 8 : 4)
        .accessibilityElement(children: .combine)
    }

    private var headerLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, PirateTheme.accentColor.opacity(0.65)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: 70, maxHeight: 1)
    }
}

private struct PirateCardSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let textureIntensity: Double

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    PirateTheme.cardGradient
                    PirateCardTexture(intensity: textureIntensity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                PirateTheme.accentColor.opacity(0.3),
                                Color.white.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
    }
}

extension View {
    func pirateCardSurface(
        cornerRadius: CGFloat = 16,
        textureIntensity: Double = 0.045
    ) -> some View {
        modifier(
            PirateCardSurfaceModifier(
                cornerRadius: cornerRadius,
                textureIntensity: textureIntensity
            )
        )
    }
}

struct PiratePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
