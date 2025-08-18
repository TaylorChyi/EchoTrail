import SpriteKit

protocol GameCoreDelegate: AnyObject {
    var world: SKNode { get }
    func cellSize() -> CGSize
    func pointFor(_ p: IntPoint) -> CGPoint
    func updateHUD(score: Int, multiplier: Double, time: Double, echoPeak: Int)
    func showGameOver(message: String)
    func hideGameOver()
}

/// Central gameplay engine handling ticks, state transitions
/// and difficulty progression. Rendering is delegated out via
/// `GameCoreDelegate`.
final class GameCore {
    enum State { case idle, playing, paused, over }
    enum Ball { case white, gold }

    weak var delegate: GameCoreDelegate?

    private(set) var state: State = .idle

    private let entitySystem = EntitySystem()
    private let worldBuilder = WorldBuilder()

    private var player: PlayerEntity!
    private var echoes: [EchoEntity] = []
    private var obstacles: [ObstacleEntity] = []
    private var balls: [IntPoint: Ball] = [:]

    private var posHistory: [IntPoint] = []
    private var continuousDir: String? = nil
    private var waitingHold = false

    // tick bookkeeping
    private var tickRate: Double = GameConfig.tickBase
    private var tickInterval: TimeInterval { 1.0 / tickRate }
    private var lastUpdate: TimeInterval = 0
    private var acc: TimeInterval = 0
    private var t: Int = 0
    private var score = 0
    private var multiplier: Double = 1.0
    private var multExpire: Int = -1
    private var epeak = 0
    private var nextEchoSpawn = GameConfig.echoDelay
    private var lastBallSpawn = 0
    private var lastSpeedUp = 0

    /// Prepare a new game in idle state.
    func configure() {
        guard let delegate else { return }
        delegate.hideGameOver()
        let build = worldBuilder.buildMap(delegate: delegate, system: entitySystem)
        player = build.player
        obstacles = build.obstacles
        balls = build.balls
        echoes.removeAll()
        posHistory.removeAll()
        score = 0; multiplier = 1; multExpire = -1; epeak = 0
        t = 0; tickRate = GameConfig.tickBase; acc = 0; lastUpdate = 0
        nextEchoSpawn = GameConfig.echoDelay
        lastBallSpawn = 0; lastSpeedUp = 0
        state = .idle
        delegate.updateHUD(score: score, multiplier: multiplier, time: 0, echoPeak: epeak)
        GameAudio.shared.stopMusic()
        GameAudio.shared.playMenu()
    }

    /// Advance gameplay with the SpriteKit update loop.
    func update(currentTime: TimeInterval) {
        guard state == .playing else { return }
        if lastUpdate == 0 { lastUpdate = currentTime }
        acc += currentTime - lastUpdate
        lastUpdate = currentTime
        while acc >= tickInterval {
            tick()
            acc -= tickInterval
        }
    }

    private func tick() {
        let cmd = waitingHold ? "W" : (continuousDir ?? "W")
        let dmap = ["U":(0,1),"D":(0,-1),"L":(-1,0),"R":(1,0),"W":(0,0)]
        let move = dmap[cmd] ?? (0,0)
        let moved = player.tryMove(direction: move,
                                   passable: passable(_:),
                                   pointFor: delegate!.pointFor(_:),
                                   interval: tickInterval)
        if !moved && cmd != "W" {
            GameAudio.shared.play(.bumpWall, on: delegate!.world)
        }
        posHistory.append(player.position)
        if posHistory.count > (GameConfig.echoDelay*GameConfig.echoLimit + 60) {
            _ = posHistory.removeFirst()
        }

        if t == nextEchoSpawn {
            spawnEcho()
            nextEchoSpawn += GameConfig.echoDelay
        }

        for i in (0..<echoes.count).reversed() {
            var e = echoes[i]
            guard var ud = e.node.userData else { continue }
            var path = ud["path"] as! [IntPoint]
            var cursor = ud["cursor"] as! Int
            e.previousPosition = e.position
            let p = cursor < path.count ? path[cursor] : path.last!
            e.position = p
            e.node.run(.move(to: delegate!.pointFor(e.position), duration: tickInterval*0.9))
            upgradeBall(at: e.position)
            cursor += 1
            ud["cursor"] = cursor
            e.node.userData = ud
            echoes[i] = e
            if cursor >= path.count {
                e.node.removeFromParent()
                echoes.remove(at: i)
            }
        }

        handleEchoFusion()
        entitySystem.update(deltaTime: tickInterval)

        if collideObstacles(player.position) { gameOver("撞到障碍"); return }
        for e in echoes { if collideObstacles(e.position) { gameOver("回声撞到障碍"); return } }
        if collidePlayerEcho() { gameOver("与回声相撞"); return }

        collectBall(at: player.position)
        if multExpire >= 0 && t >= multExpire { multiplier = 1; multExpire = -1 }

        if t - lastBallSpawn >= GameConfig.ballInterval {
            lastBallSpawn = t
            if balls.count < GameConfig.ballCap {
                worldBuilder.addBallRandom(gold: false,
                                           balls: &balls,
                                           delegate: delegate!,
                                           passable: passable(_:),
                                           playerPos: player.position)
            }
        }

        if t - lastSpeedUp >= GameConfig.speedStep {
            lastSpeedUp = t
            tickRate = min(20, tickRate * 1.08)
            worldBuilder.maybeAddKineticObstacle(into: &obstacles,
                                                 system: entitySystem,
                                                 delegate: delegate!,
                                                 tickInterval: tickInterval)
        }

        t += 1
        let timeSec = Double(t) / GameConfig.tickBase
        delegate!.updateHUD(score: score, multiplier: multiplier, time: timeSec, echoPeak: epeak)
    }

    // MARK: - Helpers
    private func passable(_ p: IntPoint) -> Bool {
        guard p.x >= 0, p.y >= 0, p.x < GameConfig.gridWidth, p.y < GameConfig.gridHeight else { return false }
        return !obstacles.contains { $0.position == p }
    }

    private func spawnEcho() {
        guard posHistory.count >= GameConfig.echoDelay, echoes.count < GameConfig.echoLimit else { return }
        let path = Array(posHistory.suffix(GameConfig.echoDelay))
        let start = path.first!
        let cs = delegate!.cellSize()
        let node = SKShapeNode(rectOf: CGSize(width: cs.width*0.8, height: cs.height*0.8), cornerRadius: 10)
        node.fillColor = Theme.echo
        node.strokeColor = Theme.echo.withAlphaComponent(0.9)
        node.position = delegate!.pointFor(start)
        node.alpha = 0.85
        node.zPosition = 2
        node.userData = ["path": path, "cursor": 0]
        let e = EchoEntity(position: start, delayIndex: 0, node: node)
        entitySystem.add(e, to: delegate!.world)
        echoes.append(e)
        epeak = max(epeak, echoes.count)
        GameAudio.shared.play(.echoSpawn, on: delegate!.world)
    }

    private func upgradeBall(at p: IntPoint) {
        if balls[p] == .white {
            balls[p] = .gold
            worldBuilder.refreshBallNode(at: p, balls: balls, delegate: delegate!)
            GameAudio.shared.play(.eatWhite, on: delegate!.world)
        }
    }

    private func collectBall(at p: IntPoint) {
        guard let tball = balls.removeValue(forKey: p) else { return }
        if let node = delegate?.world.childNode(withName: "ball_\(p.x)_\(p.y)") { node.removeFromParent() }
        switch tball {
        case .white:
            score += 10
            GameAudio.shared.play(.eatWhite, on: delegate!.world)
            spawnParticle(at: p, color: .white)
        case .gold:
            score += Int(30 * multiplier.rounded(.towardZero))
            multiplier = min(multiplier + 0.5, 4.0)
            multExpire = t + 50
            GameAudio.shared.play(.eatGold, on: delegate!.world)
            spawnParticle(at: p, color: Theme.goldBall)
        }
    }

    private func spawnParticle(at p: IntPoint, color: SKColor) {
        let cs = delegate!.cellSize()
        let pt = delegate!.pointFor(p)
        for _ in 0..<10 {
            let r = SKShapeNode(rectOf: CGSize(width: 4, height: 4), cornerRadius: 1)
            r.fillColor = color
            r.strokeColor = color
            r.position = pt
            r.zPosition = 10
            delegate!.world.addChild(r)
            let dx = CGFloat.random(in: -cs.width*0.1...cs.width*0.1)
            let dy = CGFloat.random(in: -cs.height*0.1...cs.height*0.1)
            r.run(.sequence([.group([.moveBy(x: dx, y: dy, duration: 0.4),
                                     .fadeOut(withDuration: 0.4)]),
                             .removeFromParent()]))
        }
    }

    private func collideObstacles(_ p: IntPoint) -> Bool {
        obstacles.contains { $0.position == p }
    }

    private func collidePlayerEcho() -> Bool {
        echoes.contains { $0.position == player.position }
    }

    private func handleEchoFusion() {
        var map: [IntPoint:[Int]] = [:]
        for (i, e) in echoes.enumerated() {
            map[e.position, default: []].append(i)
        }
        var removeIdx = Set<Int>()
        for (pos, arr) in map where arr.count >= 2 {
            for (bp, tball) in balls {
                if abs(bp.x - pos.x) + abs(bp.y - pos.y) <= 2, tball == .white {
                    balls[bp] = .gold
                    worldBuilder.refreshBallNode(at: bp, balls: balls, delegate: delegate!)
                    spawnParticle(at: bp, color: Theme.goldBall)
                }
            }
            score += 50
            multiplier = min(multiplier + 0.5, 4.0)
            multExpire = t + 50
            GameAudio.shared.play(.echoFuse, on: delegate!.world)
            for i in arr { removeIdx.insert(i) }
        }
        if !removeIdx.isEmpty {
            echoes = echoes.enumerated().filter { !removeIdx.contains($0.offset) }.map { $0.element }
        }
    }

    private func gameOver(_ reason: String) {
        state = .over
        GameAudio.shared.play(.gameOver, on: delegate!.world)
        GameAudio.shared.stopMusic()
        let timeSec = Double(t) / GameConfig.tickBase
        let message = "游戏结束：\(reason)\n分数 \(score)  生存 \(String(format: "%.1f", timeSec)) 秒\n峰值回声 \(epeak)"
        delegate?.showGameOver(message: message)
    }
}

extension GameCore: InputControllerDelegate {
    func directionChanged(to direction: String?) {
        continuousDir = direction
    }

    func holdChanged(isHolding: Bool) {
        waitingHold = isHolding
    }

    func startRequested() {
        if state == .idle || state == .over {
            configure()
            state = .playing
            GameAudio.shared.stopMusic()
            GameAudio.shared.playGame()
        }
    }
}
