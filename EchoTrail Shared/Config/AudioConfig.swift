import Foundation

/// 音频资源路径与文件名配置
enum AudioConfig {
    enum Music {
        static let menu = "bg_menu_loop.mp3"
        static let game = "bg_game_loop.mp3"
    }

    enum SFX {
        static let basePath = "Audio/SFX"
        static let eatWhite = "sfx_eat_white"
        static let eatGold = "sfx_eat_gold"
        static let echoSpawn = "sfx_echo_spawn"
        static let echoFuse = "sfx_echo_fuse"
        static let bumpWall = "sfx_bump_wall"
        static let gameOver = "sfx_game_over"
    }
}
