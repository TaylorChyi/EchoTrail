import SpriteKit

/// 全局主题色集合，统一视觉风格
enum Theme {
    /// 突出色，供 HUD 与摇杆等组件共用
    static let accent = SKColor(red: 0.45, green: 0.82, blue: 0.95, alpha: 1)

    /// 场景背景色
    static let background = SKColor(red: 0.04, green: 0.06, blue: 0.08, alpha: 1)

    /// 固定障碍与动态障碍配色
    static let obstacle = SKColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)

    /// 金色球体以及相关粒子效果
    static let goldBall = SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
}
