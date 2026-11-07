import SwiftUI

// 色・書体・角丸・余白・影は、ここだけで決める（app-quality-bar の look.md §0〜4）。
// 色は藤（lavender）の 1 系統。はなまるだけ、淡い朱（peach）を小さな印に使う。
// 半紙と墨の世界観を保つため、ライトに固定する（App の preferredColorScheme）。
enum Palette {
    // 藤の 5 段階
    /// 主な色（升目の補助線の強調・暦・帯）。L 0.83
    static let fuji = Color(hex: 0xC9BFEA)
    /// 淡い地（選択中・札の地）。L 0.94
    static let fujiSoft = Color(hex: 0xECE8F7)
    /// 白い文字を載せるボタンと小さな文字だけ。L 0.53・S 0.27
    static let fujiDeep = Color(hex: 0x7568A8)
    /// 半紙の地
    static let paper = Color(hex: 0xFBFAFC)
    /// 飾り（和綴じの糸）
    static let thread = Color(hex: 0xB9AEDD)

    // 地・文字・線
    /// 画面の地（ほぼ白、わずかに藤）
    static let ground = Color(hex: 0xF3F2F7)
    /// 墨（真っ黒にしない）
    static let ink = Color(hex: 0x2E2C3A)
    /// 補助の文字
    static let sub = Color(hex: 0x8C8A99)
    /// 細い線
    static let line = Color(hex: 0xE2DFEB)
    /// 升目の十字の補助線
    static let guide = Color(hex: 0xD9D3EE)

    // はなまる（朱の代わりの淡い peach）。小さな印だけに使う
    static let peach = Color(hex: 0xF4BBA4)
    static let peachDeep = Color(hex: 0xD9957A)

    /// 薄墨（お手本を重ねる色）
    static let usuzumi = Color(hex: 0x2E2C3A).opacity(0.2)

    /// 暦のマスの濃さ（稽古した字の数で 4 段階）
    static func calendar(level: Int) -> Color {
        switch level {
        case 0: return line.opacity(0.7)
        case 1: return fuji.opacity(0.45)
        case 2: return fuji
        default: return fujiDeep.opacity(0.85)
        }
    }
}

enum Typo {
    /// 見出し・大きな数字・字（セリフ。日本語はヒラギノ明朝になる）
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static let title = Font.system(.title2, design: .serif)
    static let heading = Font.system(.headline, design: .serif).weight(.medium)
    static let body = Font.system(.subheadline)
    static let small = Font.system(.footnote)
    static let label = Font.system(.caption).weight(.medium)
}

enum Radius {
    static let tiny: CGFloat = 6
    static let small: CGFloat = 12
    static let medium: CGFloat = 14
    static let large: CGFloat = 18
}

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

extension View {
    /// 普段の影（弱い）
    func softShadow() -> some View { shadow(color: Palette.ink.opacity(0.06), radius: 10, y: 4) }
    /// 浮いた物の影（今日の一枚）
    func liftedShadow() -> some View { shadow(color: Palette.ink.opacity(0.14), radius: 8, y: 6) }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
