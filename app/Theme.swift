import SwiftUI

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// Cursor-inspired design system: very dark neutral surfaces, low-contrast
// borders, a calm blue accent, tight radii, restrained type.
enum Theme {
    // Surfaces
    static let bg = Color(hex: 0x141414)          // app base
    static let panel = Color(hex: 0x1B1B1B)        // sidebar, headers
    static let elevated = Color(hex: 0x212121)     // inputs, bubbles, cards
    static let hover = Color(hex: 0x282828)
    // Borders
    static let border = Color(hex: 0x2E2E2E)
    static let borderSubtle = Color(hex: 0x242424)
    // Text
    static let text = Color(hex: 0xE6E6E6)
    static let textSecondary = Color(hex: 0x9A9A9A)
    static let textMuted = Color(hex: 0x6A6A6A)
    // Accent
    static let accent = Color(hex: 0x4D9CF0)
    static let accentHover = Color(hex: 0x6FB0F6)
    static let danger = Color(hex: 0xE5544B)

    // Radii
    static let radius: CGFloat = 6
    static let radiusLg: CGFloat = 9

    // Aliases kept so existing views compile; mapped to the Cursor palette.
    static let bg2 = panel
    static let lilac = text
    static let peri = textSecondary
    static let purple = accent
    static let blue = accent
    static let ink = Color(hex: 0x0E0E0E)
    static let dimText = textMuted
    static let accentBar = LinearGradient(colors: [accent, accent], startPoint: .leading, endPoint: .trailing)
    static let wordmark = LinearGradient(colors: [Color(hex: 0xEDEDED), Color(hex: 0x8A8A8A)],
                                         startPoint: .leading, endPoint: .trailing)
}

// Spacing scale.
enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// Quiet wordmark (Cursor leans neutral, not flashy).
struct Wordmark: View {
    var size: CGFloat = 15
    var body: some View {
        Text("resumemaxx")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.text)
            .kerning(0.2)
    }
}
