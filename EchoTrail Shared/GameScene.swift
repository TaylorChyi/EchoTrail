//
//  GameScene.swift
//  EchoTrail Shared
//
//  Created by 齐天乐 on 2025/8/18.
//

import SpriteKit
import AVFoundation

final class GameScene: SKScene {

    // 网格与参数
    let GRID_W = 7, GRID_H = 13
    let TICK_BASE: Double = 10
    let ECHO_DELAY = 30
    let ECHO_LIMIT = 8
    let BALL_INTERVAL = 40
    let BALL_CAP = 7
    let SPEED_STEP = 100
    let KINETIC_PERIOD = 5
    
    // 音频清单
    struct AudioBank {
        static let eatWhite = "sfx_eat_white.wav"
        static let eatGold  = "sfx_eat_gold.wav"
        static let echoSpawn = "sfx_echo_spawn.wav"
        static let echoFuse  = "sfx_echo_fuse.wav"
        static let bumpWall  = "sfx_bump_wall.wav"
        static let gameOver  = "sfx_game_over.wav"
    }

    // 状态
    enum State { case idle, playing, paused, over }
    var state: State = .idle
    var tickRate: Double = 10
    var tickInterval: Double { 1.0 / tickRate }
    var t: Int = 0
    var timeSec: Double = 0

    var score = 0
    var multiplier: Double = 1.0
    var multExpire: Int = -1
    var epeak = 0

    var nextEchoSpawn = 30
    var lastBallSpawn = 0
    var lastSpeedUp = 0

    var posHistory: [IntPoint] = []
    var input: InputController!

    // 实体
    struct Entity { var pos: IntPoint; var prev: IntPoint; var tail: [IntPoint]; var node: SKShapeNode }
    var player: Entity!
    var echoes: [Entity] = []
    enum Ball { case white, gold }
    var balls: [IntPoint: Ball] = [:]

    var obstStatic: Set<IntPoint> = []
    struct KObstacle { var path: [IntPoint]; var idx: Int; var node: SKShapeNode; var lastMoveT: Int }
    var obstKinetic: [KObstacle] = []

    // 渲染容器与 UI（User Interface（用户界面））
    let world = SKNode()
    let hud = SKNode()
    let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    let multLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    let timeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    let epeakLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    // 虚拟摇杆（iOS 使用）
    let joyBg = SKShapeNode(circleOfRadius: 75)
    let joyKnob = SKShapeNode(circleOfRadius: 32)

    // 驱动
    var lastUpdate: TimeInterval = 0
    var acc: Double = 0
    var lastBumpTick = -999

    // 便捷
    func clamp<T: Comparable>(_ v: T, _ a: T, _ b: T) -> T { min(max(v, a), b) }
    func cellSize() -> CGSize { CGSize(width: size.width/Double(GRID_W+2), height: size.height/Double(GRID_H+2)) }
    func pointFor(_ p: IntPoint) -> CGPoint {
        let cs = cellSize()
        return CGPoint(x: (Double(p.x)+1.5)*cs.width, y: (Double(p.y)+1.5)*cs.height)
    }
    func newRect(_ size: CGSize, color: SKColor) -> SKShapeNode {
        let n = SKShapeNode(rectOf: size, cornerRadius: 10)
        n.fillColor = color; n.strokeColor = color.withAlphaComponent(0.9)
        return n
    }

    // 音效文件存在性检查和安全播放
    func audioFileExists(_ filename: String) -> Bool {
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        if ext.isEmpty {
            return Bundle.main.url(forResource: name, withExtension: nil) != nil
        } else {
            return Bundle.main.url(forResource: name, withExtension: ext) != nil
        }
    }

    func playSFXIfAvailable(_ filename: String) {
        guard audioFileExists(filename) else { return }
        run(.playSoundFileNamed(filename, waitForCompletion: false))
    }

    // 生命周期
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.04, green: 0.06, blue: 0.08, alpha: 1)
        addChild(world)
        addChild(hud)
        setupHUD()
        setupJoystick()
        buildMap()
        enterIdle()
        input.onStart = { [weak self] in
            guard let self = self else { return }
            if self.state == .idle || self.state == .over {
                self.buildMap()
                self.enterPlaying()
            }
        }
    }

    func setupHUD() {
        let labs = [scoreLabel, multLabel, timeLabel, epeakLabel]
        for (i, l) in labs.enumerated() {
            l.fontSize = 14; l.fontColor = .white; l.horizontalAlignmentMode = .left
            l.position = CGPoint(x: 12, y: size.height - CGFloat(24 + i*20))
            hud.addChild(l)
        }
        updateHUD()
    }

    func setupJoystick() {
        joyBg.fillColor = SKColor(white: 1, alpha: 0.08)
        joyBg.strokeColor = SKColor(white: 1, alpha: 0.18)
        joyBg.zPosition = 1000
        joyKnob.fillColor = SKColor(red: 0.45, green: 0.82, blue: 0.95, alpha: 0.3)
        joyKnob.strokeColor = SKColor(white: 1, alpha: 0.25)
        joyKnob.zPosition = 1001
        joyBg.isHidden = true; joyKnob.isHidden = true
        hud.addChild(joyBg); hud.addChild(joyKnob)
    }

    // 地图与实体
    func buildMap() {
        world.removeAllChildren()
        echoes.removeAll()
        obstKinetic.removeAll()
        obstStatic.removeAll()
        balls.removeAll()

        score = 0; multiplier = 1; multExpire = -1; epeak = 0
        t = 0; timeSec = 0; tickRate = TICK_BASE
        nextEchoSpawn = ECHO_DELAY; lastBallSpawn = 0; lastSpeedUp = 0
        posHistory.removeAll()

        let cs = cellSize()
        player = Entity(pos: IntPoint(x: GRID_W/2, y: GRID_H-1),
                        prev: IntPoint(x: GRID_W/2, y: GRID_H-1),
                        tail: [],
                        node: newRect(CGSize(width: cs.width*0.8, height: cs.height*0.8),
                                      color: SKColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 1)))
        player.node.position = pointFor(player.pos)
        world.addChild(player.node)

        // 固定障碍
        let count = 8 + Int.random(in: 0...5)
        var attempts = 0
        while obstStatic.count < count && attempts < 200 {
            attempts += 1
            let x = Int.random(in: 0..<GRID_W)
            let y = Int.random(in: 0..<(GRID_H-3))
            if x == GRID_W/2 && y == GRID_H-1 { continue }
            let p = IntPoint(x: x, y: y)
            if y > 0 && y < GRID_H-1 {
                if obstStatic.contains(IntPoint(x:x, y:y-1)) && obstStatic.contains(IntPoint(x:x, y:y+1)) { continue }
            }
            obstStatic.insert(p)
            let n = newRect(CGSize(width: cs.width*0.9, height: cs.height*0.9),
                            color: SKColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1))
            n.position = pointFor(p)
            world.addChild(n)
        }

        // 初始球
        for _ in 0..<3 { addBallRandom(false) }
        updateHUD()
    }

    func addBallRandom(_ gold: Bool) {
        for _ in 0..<50 {
            let x = Int.random(in: 0..<GRID_W)
            let y = Int.random(in: 0..<GRID_H)
            let p = IntPoint(x:x, y:y)
            if balls[p] == nil && passable(p) && !(p == player.pos) {
                balls[p] = gold ? .gold : .white
                drawBall(p)
                break
            }
        }
    }

    func drawBall(_ p: IntPoint) {
        let cs = cellSize()
        let r = min(cs.width, cs.height) * 0.18
        let n = SKShapeNode(circleOfRadius: r)
        n.fillColor = .white; n.strokeColor = .white.withAlphaComponent(0.8)
        n.name = "ball_\(p.x)_\(p.y)"
        n.position = pointFor(p)
        world.addChild(n)
    }

    func refreshBallNode(at p: IntPoint) {
        if let node = world.childNode(withName: "ball_\(p.x)_\(p.y)") as? SKShapeNode {
            switch balls[p] ?? .white {
            case .white: node.fillColor = .white
            case .gold: node.fillColor = SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
            }
        }
    }

    func passable(_ p: IntPoint) -> Bool {
        guard p.x >= 0, p.y >= 0, p.x < GRID_W, p.y < GRID_H else { return false }
        if obstStatic.contains(p) { return false }
        for ob in obstKinetic { let cur = ob.path[ob.idx]; if cur == p { return false } }
        return true
    }

    func pushTail(_ e: inout Entity) { e.tail.insert(e.pos, at: 0); if e.tail.count > 6 { _ = e.tail.popLast() } }

    func tryMove(_ e: inout Entity, dir: String, isPlayer: Bool) -> Bool {
        let dmap: [String:(Int,Int)] = ["U":(0,-1),"D":(0,1),"L":(-1,0),"R":(1,0),"W":(0,0)]
        let d = dmap[dir] ?? (0,0)
        let np = IntPoint(x: e.pos.x + d.0, y: e.pos.y + d.1)
        e.prev = e.pos
        if passable(np) {
            e.pos = np; pushTail(&e)
            e.node.run(.move(to: pointFor(e.pos), duration: tickInterval*0.9))
            return true
        } else {
            if isPlayer && dir != "W" && (t - lastBumpTick) > 5 {
                playSFXIfAvailable(AudioBank.bumpWall)
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                lastBumpTick = t
            }
            pushTail(&e); return false
        }
    }

    func upgradeBall(at p: IntPoint) {
        if balls[p] == .white {
            balls[p] = .gold
            refreshBallNode(at: p)
            playSFXIfAvailable(AudioBank.eatWhite)
        }
    }

    func collectBall(at p: IntPoint) {
        guard let tball = balls.removeValue(forKey: p) else { return }
        if let node = world.childNode(withName: "ball_\(p.x)_\(p.y)") { node.removeFromParent() }
        switch tball {
        case .white:
            score += 10
            playSFXIfAvailable(AudioBank.eatWhite)
            spawnParticle(at: p, color: .white)
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        case .gold:
            score += Int(30 * multiplier.rounded(.towardZero))
            multiplier = min(multiplier + 0.5, 4.0)
            multExpire = t + 50
            playSFXIfAvailable(AudioBank.eatGold)
            spawnParticle(at: p, color: SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1))
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }
    }

    func spawnParticle(at p: IntPoint, color: SKColor) {
        let cs = cellSize()
        let pt = pointFor(p)
        for _ in 0..<10 {
            let r = SKShapeNode(rectOf: CGSize(width: 4, height: 4), cornerRadius: 1)
            r.fillColor = color; r.strokeColor = color; r.position = pt; r.zPosition = 10
            world.addChild(r)
            let dx = CGFloat.random(in: -cs.width*0.1...cs.width*0.1)
            let dy = CGFloat.random(in: -cs.height*0.1...cs.height*0.1)
            r.run(.sequence([.group([.moveBy(x: dx, y: dy, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        }
    }

    func collidePlayerEcho() -> Bool { echoes.contains(where: { $0.pos == player.pos }) }

    func handleEchoFusion() {
        var map: [IntPoint:[Int]] = [:]
        for (i, e) in echoes.enumerated() { map[e.pos, default: []].append(i) }
        var removeIdx = Set<Int>()
        for (pos, arr) in map where arr.count >= 2 {
            for (bp, tball) in balls {
                if abs(bp.x - pos.x) + abs(bp.y - pos.y) <= 2, tball == .white {
                    balls[bp] = .gold
                    refreshBallNode(at: bp)
                    spawnParticle(at: bp, color: SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1))
                }
            }
            score += 50; multiplier = min(multiplier + 0.5, 4.0); multExpire = t + 50
            playSFXIfAvailable(AudioBank.echoFuse)
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            for i in arr { removeIdx.insert(i) }
        }
        if !removeIdx.isEmpty {
            echoes = echoes.enumerated().filter { !removeIdx.contains($0.offset) }.map { $0.element }
        }
    }

    func spawnEcho() {
        guard posHistory.count >= ECHO_DELAY, echoes.count < ECHO_LIMIT else { return }
        let path = Array(posHistory.suffix(ECHO_DELAY))
        let start = path.first!
        let cs = cellSize()
        var e = Entity(pos: start, prev: start, tail: [],
                       node: newRect(CGSize(width: cs.width*0.8, height: cs.height*0.8),
                                     color: SKColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1)))
        e.node.position = pointFor(start)
        e.node.alpha = 0.85; e.node.zPosition = 2
        e.node.userData = ["path": path, "cursor": 0]
        world.addChild(e.node)
        echoes.append(e)
        epeak = max(epeak, echoes.count)
        playSFXIfAvailable(AudioBank.echoSpawn)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    func maybeAddKineticObstacle() {
        guard obstKinetic.count < 4 else { return }
        let y = Int.random(in: 0..<(GRID_H-3))
        let len = clamp(3 + Int.random(in: 0...3), 3, GRID_W-2)
        let x0 = clamp(1 + Int.random(in: 0..<(GRID_W-len-1)), 1, GRID_W-len-1)
        var path: [IntPoint] = []
        for x in x0..<(x0+len) { path.append(IntPoint(x:x, y:y)) }
        for x in stride(from: x0+len-2, to: x0, by: -1) { path.append(IntPoint(x:x, y:y)) }
        if path.contains(IntPoint(x: GRID_W/2, y: GRID_H-1)) { return }
        let node = newRect(CGSize(width: cellSize().width*0.9, height: cellSize().height*0.9),
                           color: SKColor(red: 0.28, green: 0.34, blue: 0.45, alpha: 1))
        node.position = pointFor(path.first!)
        world.addChild(node)
        obstKinetic.append(KObstacle(path: path, idx: 0, node: node, lastMoveT: t))
    }

    func collideObstacles(_ p: IntPoint) -> Bool {
        if obstStatic.contains(p) { return true }
        for ob in obstKinetic { if ob.path[ob.idx] == p { return true } }
        return false
    }

    func gameOver(_ reason: String) {
        state = .over
        playSFXIfAvailable(AudioBank.gameOver)
        GameAudio.shared.stopMusic()
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
        let label = SKLabelNode(text: "游戏结束：\(reason)  分数 \(score)  生存 \(String(format: "%.1f", timeSec)) 秒  峰值回声 \(epeak)")
        label.fontName = "Menlo-Bold"; label.fontSize = 14; label.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(label)
    }

    // 主更新
    override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime }
        acc += currentTime - lastUpdate
        lastUpdate = currentTime
        while acc >= tickInterval && state == .playing {
            tick()
            acc -= tickInterval
        }
    }

    func tick() {
        let cmd = input.isWaiting ? "W" : (input.currentDirection ?? "W")
        _ = tryMove(&player, dir: cmd, isPlayer: true)
        posHistory.append(player.pos); if posHistory.count > (ECHO_DELAY*ECHO_LIMIT + 60) { _ = posHistory.removeFirst() }

        if t == nextEchoSpawn { spawnEcho(); nextEchoSpawn += ECHO_DELAY }

        // 回声逐 Tick（时钟刻）沿记录路径行进
        for i in (0..<echoes.count).reversed() {
            var e = echoes[i]
            guard var ud = e.node.userData else { continue }
            var path = ud["path"] as! [IntPoint]
            var cursor = ud["cursor"] as! Int
            e.prev = e.pos
            let p = cursor < path.count ? path[cursor] : path.last!
            e.pos = p
            e.node.run(.move(to: pointFor(e.pos), duration: tickInterval*0.9))
            upgradeBall(at: e.pos)
            cursor += 1
            ud["cursor"] = cursor
            e.node.userData = ud
            echoes[i] = e
            if cursor >= path.count { e.node.removeFromParent(); echoes.remove(at: i) }
        }

        // 回声合鸣
        handleEchoFusion()

        // 动态障碍移动
        if t % KINETIC_PERIOD == 0 {
            for i in 0..<obstKinetic.count {
                var ob = obstKinetic[i]
                ob.idx = (ob.idx + 1) % ob.path.count
                ob.lastMoveT = t
                ob.node.run(.move(to: pointFor(ob.path[ob.idx]), duration: tickInterval*Double(KINETIC_PERIOD)))
                obstKinetic[i] = ob
            }
        }

        // 碰撞
        if collideObstacles(player.pos) { gameOver("撞到障碍"); return }
        for e in echoes { if collideObstacles(e.pos) { gameOver("回声撞到障碍"); return } }
        if collidePlayerEcho() { gameOver("与回声相撞"); return }

        // 拾取
        collectBall(at: player.pos)
        if multExpire >= 0 && t >= multExpire { multiplier = 1.0; multExpire = -1 }

        // 补球
        if t - lastBallSpawn >= BALL_INTERVAL {
            lastBallSpawn = t
            if balls.count < BALL_CAP { addBallRandom(false) }
        }

        // 难度提升
        if t - lastSpeedUp >= SPEED_STEP {
            lastSpeedUp = t
            tickRate = min(20, tickRate * 1.08)
            maybeAddKineticObstacle()
        }

        t += 1
        timeSec = Double(t) / TICK_BASE
        updateHUD()
    }

    func updateHUD() {
        scoreLabel.text = "分数 \(score)"
        multLabel.text = String(format: "倍数 %.1f×", multiplier)
        timeLabel.text = String(format: "时间 %.1fs", timeSec)
        epeakLabel.text = "回声 \(epeak)"
    }

    // 状态切换
    func enterIdle() { state = .idle; GameAudio.shared.stopMusic(); GameAudio.shared.playMenu() }
    func enterPlaying() { state = .playing; GameAudio.shared.stopMusic(); GameAudio.shared.playGame() }

    // 触控（iOS）
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesBegan(touches, with: event, in: self)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesMoved(touches, with: event, in: self)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesEnded(touches, with: event, in: self)
    }
    #endif

    // 键盘（macOS 或外接键盘）
    #if os(macOS)
    override func keyDown(with event: NSEvent) {
        input.keyDown(event, in: self)
    }
    override func keyUp(with event: NSEvent) {
        input.keyUp(event, in: self)
    }
    #endif
}
