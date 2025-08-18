import SpriteKit

struct WorldState {
    var player: PlayerEntity
    var obstacles: [ObstacleEntity]
    var balls: [IntPoint: GameCore.Ball]
    var ballNodes: [IntPoint: SKShapeNode]
}

final class WorldBuilder {
    func build(core: GameCore,
               addNode: (SKNode) -> Void,
               entitySystem: EntitySystem) -> WorldState {
        let cs = core.cellSize()
        let playerNode = core.newRect(CGSize(width: cs.width * 0.8, height: cs.height * 0.8),
                                      color: SKColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 1))
        let player = PlayerEntity(position: IntPoint(x: core.GRID_W/2, y: core.GRID_H-1),
                                  node: playerNode)
        player.node.position = core.pointFor(player.position)
        entitySystem.add(player, addNode: addNode)

        var obstacles: [ObstacleEntity] = []
        let count = 8 + Int.random(in: 0...5)
        var attempts = 0
        while obstacles.count < count && attempts < 200 {
            attempts += 1
            let x = Int.random(in: 0..<core.GRID_W)
            let y = Int.random(in: 0..<(core.GRID_H-3))
            if x == core.GRID_W/2 && y == core.GRID_H-1 { continue }
            let p = IntPoint(x: x, y: y)
            if y > 0 && y < core.GRID_H-1 {
                if obstacles.contains(where: { $0.position == IntPoint(x: x, y: y-1) }) &&
                   obstacles.contains(where: { $0.position == IntPoint(x: x, y: y+1) }) { continue }
            }
            let n = core.newRect(CGSize(width: cs.width * 0.9, height: cs.height * 0.9),
                                 color: SKColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1))
            n.position = core.pointFor(p)
            let ob = ObstacleEntity(position: p, node: n, pointFor: core.pointFor(_:))
            obstacles.append(ob)
            entitySystem.add(ob, addNode: addNode)
        }

        var balls: [IntPoint: GameCore.Ball] = [:]
        var ballNodes: [IntPoint: SKShapeNode] = [:]
        for _ in 0..<3 {
            addBallRandom(gridW: core.GRID_W,
                          gridH: core.GRID_H,
                          cellSize: cs,
                          balls: &balls,
                          ballNodes: &ballNodes,
                          passable: { pos in !obstacles.contains { $0.position == pos } },
                          pointFor: core.pointFor(_:),
                          addNode: addNode,
                          gold: false)
        }

        return WorldState(player: player,
                          obstacles: obstacles,
                          balls: balls,
                          ballNodes: ballNodes)
    }

    func addBallRandom(gridW: Int,
                       gridH: Int,
                       cellSize: CGSize,
                       balls: inout [IntPoint: GameCore.Ball],
                       ballNodes: inout [IntPoint: SKShapeNode],
                       passable: (IntPoint) -> Bool,
                       pointFor: (IntPoint) -> CGPoint,
                       addNode: (SKNode) -> Void,
                       gold: Bool) {
        for _ in 0..<50 {
            let x = Int.random(in: 0..<gridW)
            let y = Int.random(in: 0..<gridH)
            let p = IntPoint(x: x, y: y)
            if balls[p] == nil && passable(p) {
                balls[p] = gold ? .gold : .white
                let r = min(cellSize.width, cellSize.height) * 0.18
                let n = SKShapeNode(circleOfRadius: r)
                n.fillColor = gold ? SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1) : .white
                n.strokeColor = n.fillColor.withAlphaComponent(0.8)
                n.name = "ball_\(p.x)_\(p.y)"
                n.position = pointFor(p)
                ballNodes[p] = n
                addNode(n)
                break
            }
        }
    }
}

