//
//  GameAudio.swift
//  EchoTrail
//
//  Created by 齐天乐 on 2025/8/18.
//

import AVFoundation
import SpriteKit

/// 游戏音频管理，集中处理音乐与音效。
final class GameAudio {
    static let shared = GameAudio()

    /// 背景音乐资源枚举
    enum Music {
        case menu
        case game

        /// 对应文件名
        var fileName: String {
            switch self {
            case .menu: return AudioConfig.Music.menu
            case .game: return AudioConfig.Music.game
            }
        }
    }

    /// 音效资源枚举
    enum SFX: Hashable {
        case eatWhite
        case eatGold
        case echoSpawn
        case echoFuse
        case bumpWall
        case gameOver

        private static let basePath = AudioConfig.SFX.basePath

        /// 对应文件名（不含路径与后缀）
        private var fileName: String {
            switch self {
            case .eatWhite: return AudioConfig.SFX.eatWhite
            case .eatGold: return AudioConfig.SFX.eatGold
            case .echoSpawn: return AudioConfig.SFX.echoSpawn
            case .echoFuse: return AudioConfig.SFX.echoFuse
            case .bumpWall: return AudioConfig.SFX.bumpWall
            case .gameOver: return AudioConfig.SFX.gameOver
            }
        }

        /// 完整文件路径
        var filePath: String { "\(SFX.basePath)/\(fileName).mp3" }
    }

    private var musicPlayer: AVAudioPlayer?
    private var fadingPlayer: AVAudioPlayer?
    private var link: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var fadeDur: CFTimeInterval = 0.45
    private var currentTrack: Music?
    private var sfxActions: [SFX: SKAction] = [:]

    private init() {}

    // 对外接口
    func playMenu() { crossfade(to: .menu) }
    func playGame() { crossfade(to: .game) }
    func stopMusic() {
        musicPlayer?.stop(); musicPlayer = nil
        fadingPlayer?.stop(); fadingPlayer = nil
        link?.invalidate(); link = nil
    }

    // 交叉淡入淡出
    private func crossfade(to track: Music) {
        guard currentTrack != track else { return } // 同曲则不切
        currentTrack = track
        let file = track.fileName
        let next = makePlayer(file)
        next?.volume = 0
        next?.numberOfLoops = -1
        next?.prepareToPlay()
        next?.play()

        // 旧播放器进入淡出
        fadingPlayer?.stop()
        fadingPlayer = musicPlayer

        musicPlayer = next
        startDisplayLink()
    }

    private func makePlayer(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            print("Audio file not found: \(name)")
            return nil
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.enableRate = false
            return p
        } catch {
            print("Audio player error for \(name): \(error)")
            return nil
        }
    }

    private func startDisplayLink() {
        link?.invalidate()
        link = CADisplayLink(target: self, selector: #selector(step))
        startTime = CACurrentMediaTime()
        link?.add(to: .main, forMode: .common)
    }

    func play(_ sfx: SFX, on node: SKNode) {
        let action: SKAction
        if let cached = sfxActions[sfx] {
            action = cached
        } else {
            let path = sfx.filePath
            guard Bundle.main.path(forResource: path, ofType: nil) != nil else {
                print("SFX file not found: \(path)")
                return
            }
            let newAction = SKAction.playSoundFileNamed(path, waitForCompletion: false)
            sfxActions[sfx] = newAction
            action = newAction
        }
        node.run(action)
    }

    @objc private func step() {
        let t = CACurrentMediaTime() - startTime
        let k = min(max(t / fadeDur, 0), 1)
        musicPlayer?.volume = Float(k)         // 淡入
        fadingPlayer?.volume = Float(1 - k)    // 淡出
        if k >= 1 {
            fadingPlayer?.stop(); fadingPlayer = nil
            link?.invalidate(); link = nil
        }
    }
}
