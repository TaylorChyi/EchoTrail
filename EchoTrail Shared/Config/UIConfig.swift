import CoreGraphics

/// 统一 UI 样式配置
enum UIConfig {
    enum Font {
        static let primary = "Menlo-Bold"
        static let hudSize: CGFloat = 14
    }

    enum HUD {
        static let lineHeight: CGFloat = 24
        static let padding: CGFloat = 12
        static let corner: CGFloat = 12
        static let width: CGFloat = 160
    }

    enum GameOverOverlay {
        static let padding: CGFloat = 20
        static let corner: CGFloat = 16
    }
}
