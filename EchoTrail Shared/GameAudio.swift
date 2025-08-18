//
//  GameAudio.swift
//  EchoTrail
//
//  Created by 齐天乐 on 2025/8/18.
//

import AVFoundation

final class GameAudio {
    static let shared = GameAudio()

    private var musicPlayer: AVAudioPlayer?
    private var fadingPlayer: AVAudioPlayer?
    private var link: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var fadeDur: CFTimeInterval = 0.45
    private var targetName: String = ""

    private init() { }

    // 对外接口
    func playMenu() { crossfade(to: "bg_menu_loop.caf") }
    func playGame() { crossfade(to: "bg_game_loop.caf") }
    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
        fadingPlayer?.stop()
        fadingPlayer = nil
        link?.invalidate()
        link = nil
    }

    // 交叉淡入淡出
    private func crossfade(to file: String) {
        guard targetName != file else { return } // 同曲则不切
        targetName = file
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

    @objc private func step() {
        let t = CACurrentMediaTime() - startTime
        let k = min(max(t / fadeDur, 0), 1)
        musicPlayer?.volume = Float(k)         // 淡入
        fadingPlayer?.volume = Float(1 - k)    // 淡出
        if k >= 1 {
            fadingPlayer?.stop()
            fadingPlayer = nil
            link?.invalidate()
            link = nil
        }
    }
}
