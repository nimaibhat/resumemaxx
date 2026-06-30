import SwiftUI

// resumemaxx baby-blue to purple palette, shared across the app.
enum Theme {
    static let blue = Color(red: 0.59, green: 0.77, blue: 1.00)   // #96C5FF
    static let peri = Color(red: 0.65, green: 0.70, blue: 1.00)   // #A7B2FF
    static let lilac = Color(red: 0.77, green: 0.67, blue: 1.00)  // #C5ABFF
    static let purple = Color(red: 0.69, green: 0.58, blue: 1.00) // #B094FF
    static let ink = Color(red: 0.10, green: 0.09, blue: 0.15)
    static let bg = Color(red: 0.106, green: 0.090, blue: 0.149)  // #1B1726
    static let bg2 = Color(red: 0.149, green: 0.125, blue: 0.212) // #262036
    static let dimText = Color(red: 0.44, green: 0.42, blue: 0.52)

    // Left to right wordmark gradient.
    static let wordmark = LinearGradient(
        colors: [blue, peri, lilac, purple],
        startPoint: .leading, endPoint: .trailing
    )

    static let accentBar = LinearGradient(
        colors: [blue, purple],
        startPoint: .leading, endPoint: .trailing
    )
}

// The resumemaxx wordmark as styled text (no figlet needed in a real GUI).
struct Wordmark: View {
    var size: CGFloat = 22
    var body: some View {
        Text("resumemaxx")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .overlay(Theme.wordmark)
            .mask(
                Text("resumemaxx")
                    .font(.system(size: size, weight: .heavy, design: .rounded))
            )
    }
}
