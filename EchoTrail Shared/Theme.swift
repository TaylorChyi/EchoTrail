import SpriteKit

/// 全局主题与 UI 配置，统一视觉风格
enum Theme {
    /// 突出色，供 HUD 与摇杆等组件共用
    static let accent = SKColor(red: 0.45, green: 0.82, blue: 0.95, alpha: 1)
    /// 场景背景色
    static let background = SKColor(red: 0.04, green: 0.06, blue: 0.08, alpha: 1)
    /// 玩家主体颜色
    static let player = SKColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 1)
    /// 静态障碍颜色
    static let obstacle = SKColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)
    /// 动态障碍颜色
    static let kineticObstacle = SKColor(red: 0.28, green: 0.34, blue: 0.45, alpha: 1)
    /// 回声实体颜色
    static let echo = SKColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1)
    /// 金球颜色
    static let goldBall = SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)

    /// 字体与字号配置
    enum Font {
        static let primary = "Menlo-Bold"
        static let hudSize: CGFloat = 14
    }

    /// HUD 相关尺寸配置
    enum HUD {
        static let lineHeight: CGFloat = 24
        static let padding: CGFloat = 12
        static let corner: CGFloat = 12
        static let width: CGFloat = 160
    }

    /// 游戏结束覆盖层配置
    enum GameOverOverlay {
        static let padding: CGFloat = 20
        static let corner: CGFloat = 16
    }
}
