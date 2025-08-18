import SpriteKit

/// 负责地图、初始障碍和球体的生成
final class WorldBuilder {
    private let gridW: Int
    private let gridH: Int

    init(gridW: Int, gridH: Int) {
        self.gridW = gridW
        self.gridH = gridH
    }

    /// 构建初始世界并重置所有实体
    func build(using system: EntitySystem,
               delegate: GameCoreDelegate,
               cellSize: CGSize,
               pointFor: (IntPoint) -> CGPoint) {
        delegate.hideGameOver()
        delegate.worldNode.removeAllChildren()
        system.reset()

        let playerPos = IntPoint(x: gridW/2, y: gridH-1)
        let playerNode = newRect(CGSize(width: cellSize.width*0.8, height: cellSize.height*0.8),
                                 color: SKColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 1))
        playerNode.position = pointFor(playerPos)
        delegate.worldNode.addChild(playerNode)
        system.player = EntitySystem.Entity(pos: playerPos, prev: playerPos, tail: [], node: playerNode)

        // 固定障碍
        let count = 8 + Int.random(in: 0...5)
        var attempts = 0
        while system.obstStatic.count < count && attempts < 200 {
            attempts += 1
            let x = Int.random(in: 0..<gridW)
            let y = Int.random(in: 0..<(gridH-3))
            if x == gridW/2 && y == gridH-1 { continue }
            let p = IntPoint(x: x, y: y)
            if y > 0 && y < gridH-1 {
                if system.obstStatic.contains(IntPoint(x:x, y:y-1)) &&
                    system.obstStatic.contains(IntPoint(x:x, y:y+1)) { continue }
            }
            system.obstStatic.insert(p)
            let n = newRect(CGSize(width: cellSize.width*0.9, height: cellSize.height*0.9),
                            color: SKColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1))
            n.position = pointFor(p)
            delegate.worldNode.addChild(n)
        }

        // 初始球
        for _ in 0..<3 { addBallRandom(system: system, gold: false, cellSize: cellSize, pointFor: pointFor, delegate: delegate) }
    }

    /// 随机生成球体
    func addBallRandom(system: EntitySystem,
                       gold: Bool,
                       cellSize: CGSize,
                       pointFor: (IntPoint) -> CGPoint,
                       delegate: GameCoreDelegate) {
        for _ in 0..<50 {
            let x = Int.random(in: 0..<gridW)
            let y = Int.random(in: 0..<gridH)
            let p = IntPoint(x:x, y:y)
            if system.balls[p] == nil &&
                system.passable(p, gridW: gridW, gridH: gridH) &&
                !(p == system.player.pos) {
                system.balls[p] = gold ? .gold : .white
                drawBall(at: p, type: system.balls[p]!, cellSize: cellSize, pointFor: pointFor, delegate: delegate)
                break
            }
        }
    }

    /// 绘制球体节点
    private func drawBall(at p: IntPoint,
                          type: EntitySystem.Ball,
                          cellSize: CGSize,
                          pointFor: (IntPoint) -> CGPoint,
                          delegate: GameCoreDelegate) {
        let r = min(cellSize.width, cellSize.height) * 0.18
        let n = SKShapeNode(circleOfRadius: r)
        switch type {
        case .white: n.fillColor = .white; n.strokeColor = .white.withAlphaComponent(0.8)
        case .gold: n.fillColor = SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
                     n.strokeColor = n.fillColor.withAlphaComponent(0.8)
        }
        n.name = "ball_\(p.x)_\(p.y)"
        n.position = pointFor(p)
        delegate.worldNode.addChild(n)
    }

    /// 创建带圆角的矩形节点
    private func newRect(_ size: CGSize, color: SKColor) -> SKShapeNode {
        let n = SKShapeNode(rectOf: size, cornerRadius: 10)
        n.fillColor = color
        n.strokeColor = color.withAlphaComponent(0.9)
        return n
    }
}

