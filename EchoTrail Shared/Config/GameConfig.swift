import Foundation

/// 游戏运行参数集中配置，便于全局维护
enum GameConfig {
    static let gridWidth = 7
    static let gridHeight = 13
    static let tickBase: Double = 10
    static let echoDelay = 30
    static let echoLimit = 8
    static let ballInterval = 40
    static let ballCap = 7
    static let speedStep = 100
    static let kineticPeriod = 5
}
