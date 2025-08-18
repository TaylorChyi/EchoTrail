import SpriteKit

/// Represents any interactive object in the game world.
/// Entities own their spatial information and a render node that is
/// eventually attached to the scene graph.
protocol GameEntity: AnyObject {
    /// Logical position in the grid.
    var position: IntPoint { get set }

    /// SpriteKit node used for rendering.
    var node: SKNode { get }

    /// Per frame update hook.
    /// - Parameter deltaTime: Time elapsed since last update.
    func update(deltaTime: TimeInterval)
}

/// Entities that keep a trail of previous positions and support grid based
/// movement can conform to `TailEntity` to gain shared behaviour such as
/// pushing tail segments and attempting moves on the grid.
protocol TailEntity: GameEntity {
    /// Previous grid position; useful for movement interpolation.
    var previousPosition: IntPoint { get set }

    /// Ordered list of past positions forming the tail.
    var tail: [IntPoint] { get set }
}

extension TailEntity {
    /// Pushes the current position to the head of the tail.
    /// - Parameter limit: Maximum length of the tail.
    func pushTail(limit: Int = 6) {
        tail.insert(position, at: 0)
        if tail.count > limit { tail.removeLast() }
    }

    /// Attempts to move the entity in the given direction on a grid.
    ///
    /// - Parameters:
    ///   - direction: Direction vector measured in grid units.
    ///   - passable: Closure determining if a cell can be entered.
    ///   - pointFor: Maps a grid point to a SpriteKit coordinate.
    ///   - interval: Animation interval for node movement.
    /// - Returns: `true` if the entity moved to a new cell.
    @discardableResult
    func tryMove(direction: (Int, Int),
                 passable: (IntPoint) -> Bool,
                 pointFor: (IntPoint) -> CGPoint,
                 interval: TimeInterval) -> Bool {
        let np = IntPoint(x: position.x + direction.0,
                          y: position.y + direction.1)
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

/// Player controlled entity.
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

/// Follows the player's previous positions with a delay.
final class EchoEntity: TailEntity {
    var position: IntPoint
    var previousPosition: IntPoint
    var tail: [IntPoint] = []
    let node: SKShapeNode
    /// Index offset into the player's history that this echo follows.
    var delayIndex: Int

    init(position: IntPoint, delayIndex: Int, node: SKShapeNode) {
        self.position = position
        self.previousPosition = position
        self.delayIndex = delayIndex
        self.node = node
    }

    func update(deltaTime: TimeInterval) { }
}

/// Static or kinetic obstacle occupying cells on the grid.
final class ObstacleEntity: GameEntity {
    var position: IntPoint
    let node: SKShapeNode

    /// Path for kinetic obstacles; empty for static ones.
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

/// Central manager responsible for keeping track of all entities and
/// propagating update calls.
final class EntitySystem {
    private(set) var entities: [GameEntity] = []

    func add(_ entity: GameEntity, to scene: SKNode) {
        entities.append(entity)
        scene.addChild(entity.node)
    }

    func removeAll() {
        entities.removeAll()
    }

    /// Updates every managed entity.
    func update(deltaTime: TimeInterval) {
        for entity in entities {
            entity.update(deltaTime: deltaTime)
        }
    }
}

