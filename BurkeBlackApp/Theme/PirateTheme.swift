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
