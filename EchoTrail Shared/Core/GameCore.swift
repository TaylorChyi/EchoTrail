import SpriteKit

protocol GameCoreDelegate: AnyObject {
    var worldNode: SKNode { get }
    func updateHUD(score: Int, multiplier: Double, time: Double, echoPeak: Int)
    func showGameOver(message: String)
    func hideGameOver()
    func spawnParticle(at p: IntPoint, color: SKColor)
}

/// 负责 Tick、状态转移与难度提升等核心游戏逻辑
final class GameCore {
    // 网格与参数
    let GRID_W = 7, GRID_H = 13
    let TICK_BASE: Double = 10
    let ECHO_DELAY = 30
    let ECHO_LIMIT = 8
    let BALL_INTERVAL = 40
    let BALL_CAP = 7
    let SPEED_STEP = 100
    let KINETIC_PERIOD = 5

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
    var continuousDir: String? = nil
    var waitingHold = false

    private let entities = EntitySystem()
    private let builder: WorldBuilder
    private weak var delegate: GameCoreDelegate?
    private var sceneSize: CGSize

    // 驱动
    private var lastUpdate: TimeInterval = 0
    private var acc: Double = 0
    private var lastBumpTick = -999

    init(delegate: GameCoreDelegate, sceneSize: CGSize) {
        self.delegate = delegate
        self.sceneSize = sceneSize
        builder = WorldBuilder(gridW: GRID_W, gridH: GRID_H)
    }

    // MARK: - 公用工具
    func cellSize() -> CGSize {
        CGSize(width: sceneSize.width/Double(GRID_W+2), height: sceneSize.height/Double(GRID_H+2))
    }
    func pointFor(_ p: IntPoint) -> CGPoint {
        let cs = cellSize()
        return CGPoint(x: (Double(p.x)+1.5)*cs.width, y: (Double(p.y)+1.5)*cs.height)
    }

    // MARK: - 生命周期
    func start() {
        buildMap()
        enterIdle()
    }

    func buildMap() {
        score = 0; multiplier = 1; multExpire = -1; epeak = 0
        t = 0; timeSec = 0; tickRate = TICK_BASE
        nextEchoSpawn = ECHO_DELAY; lastBallSpawn = 0; lastSpeedUp = 0
        posHistory.removeAll()

        builder.build(using: entities,
                      delegate: delegate!,
                      cellSize: cellSize(),
                      pointFor: { [weak self] in self!.pointFor($0) })
        updateHUD()
    }

    // MARK: - 状态
    func enterIdle() { state = .idle; GameAudio.shared.stopMusic(); GameAudio.shared.playMenu() }
    func enterPlaying() { state = .playing; GameAudio.shared.stopMusic(); GameAudio.shared.playGame() }

    func startPlayingIfNeeded() {
        if state == .idle || state == .over { buildMap(); enterPlaying() }
    }

    // MARK: - 输入
    func updateDirection(_ dir: String?) { continuousDir = dir }
    func setHold(_ hold: Bool) { waitingHold = hold }

    // MARK: - 主更新
    func update(currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime }
        acc += currentTime - lastUpdate
        lastUpdate = currentTime
        while acc >= tickInterval && state == .playing {
            tick()
            acc -= tickInterval
        }
    }

    private func tick() {
        let cmd = waitingHold ? "W" : (continuousDir ?? "W")
        _ = entities.tryMove(&entities.player, dir: cmd, gridW: GRID_W, gridH: GRID_H)
        entities.player.node.run(.move(to: pointFor(entities.player.pos), duration: tickInterval*0.9))
        posHistory.append(entities.player.pos)
        if posHistory.count > (ECHO_DELAY*ECHO_LIMIT + 60) { _ = posHistory.removeFirst() }

        if t == nextEchoSpawn { spawnEcho(); nextEchoSpawn += ECHO_DELAY }

        // 回声逐 Tick 沿记录路径行进
        for i in (0..<entities.echoes.count).reversed() {
            var e = entities.echoes[i]
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
            entities.echoes[i] = e
            if cursor >= path.count { e.node.removeFromParent(); entities.echoes.remove(at: i) }
        }

        handleEchoFusion()

        // 动态障碍移动
        if t % KINETIC_PERIOD == 0 {
            for i in 0..<entities.obstKinetic.count {
                var ob = entities.obstKinetic[i]
                ob.idx = (ob.idx + 1) % ob.path.count
                ob.lastMoveT = t
                ob.node.run(.move(to: pointFor(ob.path[ob.idx]), duration: tickInterval*Double(KINETIC_PERIOD)))
                entities.obstKinetic[i] = ob
            }
        }

        // 碰撞
        if collideObstacles(entities.player.pos) { gameOver("撞到障碍"); return }
        for e in entities.echoes { if collideObstacles(e.pos) { gameOver("回声撞到障碍"); return } }
        if collidePlayerEcho() { gameOver("与回声相撞"); return }

        // 拾取
        collectBall(at: entities.player.pos)
        if multExpire >= 0 && t >= multExpire { multiplier = 1.0; multExpire = -1 }

        // 补球
        if t - lastBallSpawn >= BALL_INTERVAL {
            lastBallSpawn = t
            if entities.balls.count < BALL_CAP {
                builder.addBallRandom(system: entities,
                                      gold: false,
                                      cellSize: cellSize(),
                                      pointFor: { [weak self] in self!.pointFor($0) },
                                      delegate: delegate!)
            }
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

    // MARK: - HUD
    private func updateHUD() {
        delegate?.updateHUD(score: score, multiplier: multiplier, time: timeSec, echoPeak: epeak)
    }

    // MARK: - 业务逻辑
    private func upgradeBall(at p: IntPoint) {
        if entities.balls[p] == .white {
            entities.balls[p] = .gold
            refreshBallNode(at: p)
            GameAudio.shared.play(.eatWhite, on: delegate as? SKScene)
        }
    }

    private func refreshBallNode(at p: IntPoint) {
        if let node = delegate?.worldNode.childNode(withName: "ball_\(p.x)_\(p.y)") as? SKShapeNode {
            switch entities.balls[p] ?? .white {
            case .white: node.fillColor = .white
            case .gold: node.fillColor = SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
            }
        }
    }

    private func collectBall(at p: IntPoint) {
        guard let tball = entities.balls.removeValue(forKey: p) else { return }
        if let node = delegate?.worldNode.childNode(withName: "ball_\(p.x)_\(p.y)") {
            node.removeFromParent()
        }
        switch tball {
        case .white:
            score += 10
            GameAudio.shared.play(.eatWhite, on: delegate as? SKScene)
            delegate?.spawnParticle(at: p, color: .white)
        case .gold:
            score += Int(30 * multiplier.rounded(.towardZero))
            multiplier = min(multiplier + 0.5, 4.0)
            multExpire = t + 50
            GameAudio.shared.play(.eatGold, on: delegate as? SKScene)
            delegate?.spawnParticle(at: p, color: SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1))
        }
    }

    private func spawnParticle(at p: IntPoint, color: SKColor) {
        delegate?.spawnParticle(at: p, color: color)
    }

    private func collidePlayerEcho() -> Bool {
        entities.echoes.contains(where: { $0.pos == entities.player.pos })
    }

    private func handleEchoFusion() {
        var map: [IntPoint:[Int]] = [:]
        for (i, e) in entities.echoes.enumerated() { map[e.pos, default: []].append(i) }
        var removeIdx = Set<Int>()
        for (pos, arr) in map where arr.count >= 2 {
            for (bp, tball) in entities.balls {
                if abs(bp.x - pos.x) + abs(bp.y - pos.y) <= 2, tball == .white {
                    entities.balls[bp] = .gold
                    refreshBallNode(at: bp)
                    spawnParticle(at: bp, color: SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1))
                }
            }
            score += 50; multiplier = min(multiplier + 0.5, 4.0); multExpire = t + 50
            GameAudio.shared.play(.echoFuse, on: delegate as? SKScene)
            for i in arr { removeIdx.insert(i) }
        }
        if !removeIdx.isEmpty {
            entities.echoes = entities.echoes.enumerated().filter { !removeIdx.contains($0.offset) }.map { $0.element }
        }
    }

    private func spawnEcho() {
        guard posHistory.count >= ECHO_DELAY, entities.echoes.count < ECHO_LIMIT else { return }
        let path = Array(posHistory.suffix(ECHO_DELAY))
        let start = path.first!
        let cs = cellSize()
        var e = EntitySystem.Entity(pos: start, prev: start, tail: [],
                                    node: newRect(CGSize(width: cs.width*0.8, height: cs.height*0.8),
                                                  color: SKColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1)))
        e.node.position = pointFor(start)
        e.node.alpha = 0.85; e.node.zPosition = 2
        e.node.userData = ["path": path, "cursor": 0]
        delegate?.worldNode.addChild(e.node)
        entities.echoes.append(e)
        epeak = max(epeak, entities.echoes.count)
        GameAudio.shared.play(.echoSpawn, on: delegate as? SKScene)
    }

    private func maybeAddKineticObstacle() {
        guard entities.obstKinetic.count < 4 else { return }
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
        delegate?.worldNode.addChild(node)
        entities.obstKinetic.append(EntitySystem.KObstacle(path: path, idx: 0, node: node, lastMoveT: t))
    }

    private func collideObstacles(_ p: IntPoint) -> Bool {
        if entities.obstStatic.contains(p) { return true }
        for ob in entities.obstKinetic { if ob.path[ob.idx] == p { return true } }
        return false
    }

    private func gameOver(_ reason: String) {
        state = .over
        GameAudio.shared.play(.gameOver, on: delegate as? SKScene)
        GameAudio.shared.stopMusic()
        let message = "游戏结束：\(reason)\n分数 \(score)  生存 \(String(format: "%.1f", timeSec)) 秒\n峰值回声 \(epeak)"
        delegate?.showGameOver(message: message)
    }

    // MARK: - 便捷
    private func clamp<T: Comparable>(_ v: T, _ a: T, _ b: T) -> T { min(max(v, a), b) }
    private func newRect(_ size: CGSize, color: SKColor) -> SKShapeNode {
        let n = SKShapeNode(rectOf: size, cornerRadius: 10)
        n.fillColor = color
        n.strokeColor = color.withAlphaComponent(0.9)
        return n
    }
}

