import SpriteKit

/// Builds the world map and provides helpers for spawning
/// balls and obstacles.
final class WorldBuilder {
    func buildMap(delegate: GameCoreDelegate,
                  system: EntitySystem) -> (player: PlayerEntity, obstacles: [ObstacleEntity], balls: [IntPoint: GameCore.Ball]) {
        delegate.world.removeAllChildren()
        system.removeAll()

        var obstacles: [ObstacleEntity] = []
        var balls: [IntPoint: GameCore.Ball] = [:]
        let cs = delegate.cellSize()

        // player
        let playerNode = newRect(CGSize(width: cs.width*0.8, height: cs.height*0.8), color: Theme.player)
        let player = PlayerEntity(position: IntPoint(x: GameConfig.gridWidth/2, y: GameConfig.gridHeight-1),
                                  node: playerNode)
        player.node.position = delegate.pointFor(player.position)
        system.add(player, to: delegate.world)

        // static obstacles
        let count = 8 + Int.random(in: 0...5)
        var attempts = 0
        while obstacles.count < count && attempts < 200 {
            attempts += 1
            let x = Int.random(in: 0..<GameConfig.gridWidth)
            let y = Int.random(in: 0..<(GameConfig.gridHeight-3))
            if x == GameConfig.gridWidth/2 && y == GameConfig.gridHeight-1 { continue }
            let p = IntPoint(x: x, y: y)
            if y > 0 && y < GameConfig.gridHeight-1 {
                if obstacles.contains(where: { $0.position == IntPoint(x:x, y:y-1) }) &&
                    obstacles.contains(where: { $0.position == IntPoint(x:x, y:y+1) }) { continue }
            }
            let n = newRect(CGSize(width: cs.width*0.9, height: cs.height*0.9), color: Theme.obstacle)
            n.position = delegate.pointFor(p)
            let ob = ObstacleEntity(position: p, node: n, pointFor: delegate.pointFor(_:))
            obstacles.append(ob)
            system.add(ob, to: delegate.world)
        }

        let passable: (IntPoint) -> Bool = { p in !obstacles.contains { $0.position == p } }
        for _ in 0..<3 {
            addBallRandom(gold: false,
                          balls: &balls,
                          delegate: delegate,
                          passable: passable,
                          playerPos: player.position)
        }

        return (player, obstacles, balls)
    }

    func addBallRandom(gold: Bool,
                       balls: inout [IntPoint: GameCore.Ball],
                       delegate: GameCoreDelegate,
                       passable: (IntPoint) -> Bool,
                       playerPos: IntPoint) {
        for _ in 0..<50 {
            let x = Int.random(in: 0..<GameConfig.gridWidth)
            let y = Int.random(in: 0..<GameConfig.gridHeight)
            let p = IntPoint(x: x, y: y)
            if balls[p] == nil && passable(p) && !(p == playerPos) {
                balls[p] = gold ? .gold : .white
                drawBall(p, type: balls[p]!, delegate: delegate)
                break
            }
        }
    }

    func refreshBallNode(at p: IntPoint,
                         balls: [IntPoint: GameCore.Ball],
                         delegate: GameCoreDelegate) {
        if let node = delegate.world.childNode(withName: "ball_\(p.x)_\(p.y)") as? SKShapeNode {
            switch balls[p] ?? .white {
            case .white: node.fillColor = .white
            case .gold: node.fillColor = Theme.goldBall
            }
        }
    }

    func maybeAddKineticObstacle(into obstacles: inout [ObstacleEntity],
                                 system: EntitySystem,
                                 delegate: GameCoreDelegate,
                                 tickInterval: TimeInterval) {
        let kineticCount = obstacles.filter { !$0.path.isEmpty }.count
        guard kineticCount < 4 else { return }
        let y = Int.random(in: 0..<(GameConfig.gridHeight-3))
        let len = clamp(3 + Int.random(in: 0...3), 3, GameConfig.gridWidth-2)
        let x0 = clamp(1 + Int.random(in: 0..<(GameConfig.gridWidth-len-1)), 1, GameConfig.gridWidth-len-1)
        var path: [IntPoint] = []
        for x in x0..<(x0+len) { path.append(IntPoint(x:x, y:y)) }
        for x in stride(from: x0+len-2, to: x0, by: -1) { path.append(IntPoint(x:x, y:y)) }
        if path.contains(IntPoint(x: GameConfig.gridWidth/2, y: GameConfig.gridHeight-1)) { return }
        let node = newRect(CGSize(width: delegate.cellSize().width*0.9,
                                  height: delegate.cellSize().height*0.9),
                           color: Theme.kineticObstacle)
        node.position = delegate.pointFor(path.first!)
        let ob = ObstacleEntity(position: path.first!,
                                path: path,
                                node: node,
                                pointFor: delegate.pointFor(_:),
                                moveDuration: tickInterval * Double(GameConfig.kineticPeriod),
                                period: GameConfig.kineticPeriod)
        obstacles.append(ob)
        system.add(ob, to: delegate.world)
    }

    private func drawBall(_ p: IntPoint,
                          type: GameCore.Ball,
                          delegate: GameCoreDelegate) {
        let cs = delegate.cellSize()
        let r = min(cs.width, cs.height) * 0.18
        let n = SKShapeNode(circleOfRadius: r)
        switch type {
        case .white:
            n.fillColor = .white
            n.strokeColor = .white.withAlphaComponent(0.8)
        case .gold:
            n.fillColor = Theme.goldBall
            n.strokeColor = Theme.goldBall.withAlphaComponent(0.8)
        }
        n.name = "ball_\(p.x)_\(p.y)"
        n.position = delegate.pointFor(p)
        delegate.world.addChild(n)
    }

    private func newRect(_ size: CGSize, color: SKColor) -> SKShapeNode {
        let n = SKShapeNode(rectOf: size, cornerRadius: 10)
        n.fillColor = color
        n.strokeColor = color.withAlphaComponent(0.9)
        return n
    }

    private func clamp<T: Comparable>(_ v: T, _ a: T, _ b: T) -> T { min(max(v, a), b) }
}
