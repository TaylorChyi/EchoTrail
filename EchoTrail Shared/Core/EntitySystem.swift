import SpriteKit

protocol GameEntity: AnyObject {
    var position: IntPoint { get set }
    var node: SKNode { get }
    func update(deltaTime: TimeInterval)
}

protocol TailEntity: GameEntity {
    var previousPosition: IntPoint { get set }
    var tail: [IntPoint] { get set }
}

extension TailEntity {
    func pushTail(limit: Int = 6) {
        tail.insert(position, at: 0)
        if tail.count > limit { tail.removeLast() }
    }

    @discardableResult
    func tryMove(direction: (Int, Int),
                 passable: (IntPoint) -> Bool,
                 pointFor: (IntPoint) -> CGPoint,
                 interval: TimeInterval) -> Bool {
        let np = IntPoint(x: position.x + direction.0, y: position.y + direction.1)
        previousPosition = position
        if passable(np) {
            position = np
            pushTail()
            node.run(.move(to: pointFor(np), duration: interval * 0.9))
            return true
        } else {
            pushTail()
            return false
        }
    }
}

final class PlayerEntity: TailEntity {
    var position: IntPoint
    var previousPosition: IntPoint
    var tail: [IntPoint] = []
    let node: SKShapeNode

    init(position: IntPoint, node: SKShapeNode) {
        self.position = position
        self.previousPosition = position
        self.node = node
    }

    func update(deltaTime: TimeInterval) { }
}

final class EchoEntity: TailEntity {
    var position: IntPoint
    var previousPosition: IntPoint
    var tail: [IntPoint] = []
    let node: SKShapeNode
    var delayIndex: Int

    init(position: IntPoint, delayIndex: Int, node: SKShapeNode) {
        self.position = position
        self.previousPosition = position
        self.delayIndex = delayIndex
        self.node = node
    }

    func update(deltaTime: TimeInterval) { }
}

final class ObstacleEntity: GameEntity {
    var position: IntPoint
    let node: SKShapeNode
    var path: [IntPoint]
    var currentIndex: Int
    private let pointFor: (IntPoint) -> CGPoint
    private let moveDuration: TimeInterval
    private let period: Int
    private var tickCounter: Int = 0

    init(position: IntPoint,
         path: [IntPoint] = [],
         node: SKShapeNode,
         pointFor: @escaping (IntPoint) -> CGPoint,
         moveDuration: TimeInterval = 0.1,
         period: Int = 1) {
        self.position = position
        self.path = path
        self.currentIndex = 0
        self.node = node
        self.pointFor = pointFor
        self.moveDuration = moveDuration
        self.period = max(1, period)
    }

    func update(deltaTime: TimeInterval) {
        guard !path.isEmpty else { return }
        tickCounter += 1
        if tickCounter % period == 0 {
            currentIndex = (currentIndex + 1) % path.count
            position = path[currentIndex]
            node.run(.move(to: pointFor(position), duration: moveDuration))
        }
    }
}

final class EntitySystem {
    private(set) var entities: [GameEntity] = []

    func add(_ entity: GameEntity, addNode: (SKNode) -> Void) {
        entities.append(entity)
        addNode(entity.node)
    }

    func removeAll() {
        entities.removeAll()
    }

    func update(deltaTime: TimeInterval) {
        for entity in entities {
            entity.update(deltaTime: deltaTime)
        }
    }
}

