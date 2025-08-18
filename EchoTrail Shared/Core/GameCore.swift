import SpriteKit

protocol GameCoreDelegate: AnyObject {
    func resetWorld()
    func addNodeToWorld(_ node: SKNode)
    func updateHUD(score: Int, multiplier: Double, time: Double, echoPeak: Int)
    func showGameOver(message: String)
    func audioNode() -> SKNode
}

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

    let entitySystem = EntitySystem()
    var player: PlayerEntity!
    var echoes: [EchoEntity] = []
    enum Ball { case white, gold }
    var balls: [IntPoint: Ball] = [:]
    var ballNodes: [IntPoint: SKShapeNode] = [:]
    var obstacles: [ObstacleEntity] = []

    weak var delegate: GameCoreDelegate?
    let worldBuilder = WorldBuilder()
    var sceneSize: CGSize

    var lastUpdate: TimeInterval = 0
    var acc: Double = 0
    var lastBumpTick = -999

    init(sceneSize: CGSize, delegate: GameCoreDelegate) {
        self.sceneSize = sceneSize
        self.delegate = delegate
    }

    // 便捷
    func clamp<T: Comparable>(_ v: T, _ a: T, _ b: T) -> T { min(max(v, a), b) }
    func cellSize() -> CGSize { CGSize(width: sceneSize.width/Double(GRID_W+2), height: sceneSize.height/Double(GRID_H+2)) }
    func pointFor(_ p: IntPoint) -> CGPoint {
        let cs = cellSize()
        return CGPoint(x: (Double(p.x)+1.5)*cs.width, y: (Double(p.y)+1.5)*cs.height)
    }
    func newRect(_ size: CGSize, color: SKColor) -> SKShapeNode {
        let n = SKShapeNode(rectOf: size, cornerRadius: 10)
        n.fillColor = color; n.strokeColor = color.withAlphaComponent(0.9)
        return n
    }

    // 世界重建
    func buildWorld() {
        delegate?.resetWorld()
        entitySystem.removeAll()
        echoes.removeAll()
        obstacles.removeAll()
        balls.removeAll()
        ballNodes.removeAll()

        score = 0; multiplier = 1; multExpire = -1; epeak = 0
        t = 0; timeSec = 0; tickRate = TICK_BASE
        nextEchoSpawn = ECHO_DELAY; lastBallSpawn = 0; lastSpeedUp = 0
        posHistory.removeAll()

        let worldState = worldBuilder.build(core: self, addNode: { [weak self] node in
            self?.delegate?.addNodeToWorld(node)
        }, entitySystem: entitySystem)
        player = worldState.player
        obstacles = worldState.obstacles
        balls = worldState.balls
        ballNodes = worldState.ballNodes

        updateHUD()
    }

    // HUD
    func updateHUD() {
        delegate?.updateHUD(score: score, multiplier: multiplier, time: timeSec, echoPeak: epeak)
    }

    // 输入
    func directionChanged(to direction: String?) { continuousDir = direction }
    func holdChanged(isHolding: Bool) { waitingHold = isHolding }
    func startRequested() {
        if state == .idle || state == .over { buildWorld(); enterPlaying() }
    }

    // 状态切换
    func enterIdle() { state = .idle; GameAudio.shared.stopMusic(); GameAudio.shared.playMenu() }
    func enterPlaying() { state = .playing; GameAudio.shared.stopMusic(); GameAudio.shared.playGame() }

    // 物理
    func passable(_ p: IntPoint) -> Bool {
        guard p.x >= 0, p.y >= 0, p.x < GRID_W, p.y < GRID_H else { return false }
        return !obstacles.contains { $0.position == p }
    }

    func refreshBallNode(at p: IntPoint) {
        if let node = ballNodes[p] {
            switch balls[p] ?? .white {
            case .white: node.fillColor = .white
            case .gold: node.fillColor = SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
            }
        }
    }

    func upgradeBall(at p: IntPoint) {
        if balls[p] == .white {
            balls[p] = .gold
            refreshBallNode(at: p)
            GameAudio.shared.play(.eatWhite, on: delegate!.audioNode())
        }
    }

    func collectBall(at p: IntPoint) {
        guard let tball = balls.removeValue(forKey: p), let node = ballNodes.removeValue(forKey: p) else { return }
        node.removeFromParent()
        switch tball {
        case .white:
            score += 10
            GameAudio.shared.play(.eatWhite, on: delegate!.audioNode())
            spawnParticle(at: p, color: .white)
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        case .gold:
            score += Int(30 * multiplier.rounded(.towardZero))
            multiplier = min(multiplier + 0.5, 4.0)
            multExpire = t + 50
            GameAudio.shared.play(.eatGold, on: delegate!.audioNode())
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
            delegate?.addNodeToWorld(r)
            let dx = CGFloat.random(in: -cs.width*0.1...cs.width*0.1)
            let dy = CGFloat.random(in: -cs.height*0.1...cs.height*0.1)
            r.run(.sequence([.group([.moveBy(x: dx, y: dy, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        }
    }

    func collidePlayerEcho() -> Bool { echoes.contains(where: { $0.position == player.position }) }

    func handleEchoFusion() {
        var map: [IntPoint:[Int]] = [:]
        for (i, e) in echoes.enumerated() { map[e.position, default: []].append(i) }
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
            GameAudio.shared.play(.echoFuse, on: delegate!.audioNode())
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
        let node = newRect(CGSize(width: cs.width*0.8, height: cs.height*0.8),
                           color: SKColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1))
        node.position = pointFor(start)
        node.alpha = 0.85; node.zPosition = 2
        node.userData = ["path": path, "cursor": 0]
        let e = EchoEntity(position: start, delayIndex: 0, node: node)
        entitySystem.add(e, addNode: { [weak self] node in self?.delegate?.addNodeToWorld(node) })
        echoes.append(e)
        epeak = max(epeak, echoes.count)
        GameAudio.shared.play(.echoSpawn, on: delegate!.audioNode())
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    func maybeAddKineticObstacle() {
        let kineticCount = obstacles.filter { !$0.path.isEmpty }.count
        guard kineticCount < 4 else { return }
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
        let ob = ObstacleEntity(position: path.first!,
                                path: path,
                                node: node,
                                pointFor: pointFor(_:),
                                moveDuration: tickInterval * Double(KINETIC_PERIOD),
                                period: KINETIC_PERIOD)
        obstacles.append(ob)
        entitySystem.add(ob, addNode: { [weak self] node in self?.delegate?.addNodeToWorld(node) })
    }

    func collideObstacles(_ p: IntPoint) -> Bool {
        obstacles.contains { $0.position == p }
    }

    func gameOver(_ reason: String) {
        state = .over
        GameAudio.shared.play(.gameOver, on: delegate!.audioNode())
        GameAudio.shared.stopMusic()
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
        let message = "游戏结束：\(reason)\n分数 \(score)  生存 \(String(format: "%.1f", timeSec)) 秒\n峰值回声 \(epeak)"
        delegate?.showGameOver(message: message)
    }

    // 主更新
    func update(currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime }
        acc += currentTime - lastUpdate
        lastUpdate = currentTime
        while acc >= tickInterval && state == .playing {
            tick()
            acc -= tickInterval
        }
    }

    func tick() {
        let cmd = waitingHold ? "W" : (continuousDir ?? "W")
        let dmap: [String:(Int,Int)] = ["U":(0,1),"D":(0,-1),"L":(-1,0),"R":(1,0),"W":(0,0)]
        let move = dmap[cmd] ?? (0,0)
        let moved = player.tryMove(direction: move,
                                   passable: passable(_:),
                                   pointFor: pointFor(_:),
                                   interval: tickInterval)
        if !moved && cmd != "W" && (t - lastBumpTick) > 5 {
            GameAudio.shared.play(.bumpWall, on: delegate!.audioNode())
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            lastBumpTick = t
        }
        posHistory.append(player.position)
        if posHistory.count > (ECHO_DELAY*ECHO_LIMIT + 60) { _ = posHistory.removeFirst() }

        if t == nextEchoSpawn { spawnEcho(); nextEchoSpawn += ECHO_DELAY }

        for i in (0..<echoes.count).reversed() {
            var e = echoes[i]
            guard var ud = e.node.userData else { continue }
            var path = ud["path"] as! [IntPoint]
            var cursor = ud["cursor"] as! Int
            e.previousPosition = e.position
            let p = cursor < path.count ? path[cursor] : path.last!
            e.position = p
            e.node.run(.move(to: pointFor(e.position), duration: tickInterval*0.9))
            upgradeBall(at: e.position)
            cursor += 1
            ud["cursor"] = cursor
            e.node.userData = ud
            echoes[i] = e
            if cursor >= path.count { e.node.removeFromParent(); echoes.remove(at: i) }
        }

        handleEchoFusion()
        entitySystem.update(deltaTime: tickInterval)

        if collideObstacles(player.position) { gameOver("撞到障碍"); return }
        for e in echoes { if collideObstacles(e.position) { gameOver("回声撞到障碍"); return } }
        if collidePlayerEcho() { gameOver("与回声相撞"); return }

        collectBall(at: player.position)
        if multExpire >= 0 && t >= multExpire { multiplier = 1.0; multExpire = -1 }

        if t - lastBallSpawn >= BALL_INTERVAL {
            lastBallSpawn = t
            if balls.count < BALL_CAP {
                worldBuilder.addBallRandom(gridW: GRID_W,
                                           gridH: GRID_H,
                                           cellSize: cellSize(),
                                           balls: &balls,
                                           ballNodes: &ballNodes,
                                           passable: passable(_:),
                                           pointFor: pointFor(_:),
                                           addNode: { [weak self] node in self?.delegate?.addNodeToWorld(node) },
                                           gold: false)
            }
        }

        if t - lastSpeedUp >= SPEED_STEP {
            lastSpeedUp = t
            tickRate = min(20, tickRate * 1.08)
            maybeAddKineticObstacle()
        }

        t += 1
        timeSec = Double(t) / TICK_BASE
        updateHUD()
    }
}

