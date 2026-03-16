import SwiftUI

enum AppTheme {
    // Background colors
    static let cardBackground   = Color(red: 0.118, green: 0.118, blue: 0.125) // #1E1E20
    static let cardBorder       = Color.white.opacity(0.08)

    // State accent colors
    static let idle             = Color(red: 0.4,  green: 0.4,  blue: 0.45)
    static let listening        = Color(red: 0.2,  green: 0.5,  blue: 1.0)   // blue
    static let thinking         = Color(red: 0.8,  green: 0.6,  blue: 0.1)   // amber
    static let speaking         = Color(red: 0.2,  green: 0.75, blue: 0.45)  // green
    static let error            = Color(red: 0.9,  green: 0.3,  blue: 0.3)   // red

    // Typography
    static let labelFont        = Font.system(size: 11, weight: .medium, design: .rounded)
    static let transcriptFont   = Font.system(size: 12, weight: .regular, design: .rounded)
    static let monoFont         = Font.system(size: 10, weight: .regular, design: .monospaced)

    // Layout
    static let overlayWidth: CGFloat  = 280
    static let overlayHeight: CGFloat = 90
    static let cornerRadius: CGFloat  = 14
    static let orb: CGFloat           = 36
}
