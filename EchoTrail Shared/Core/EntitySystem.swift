import SpriteKit

/// 管理玩家、回声、球体以及障碍的统一系统，负责纯逻辑层的实体数据维护
/// 渲染交由外部委托处理，实现逻辑与表现分离
final class EntitySystem {
    struct Entity {
        var pos: IntPoint
        var prev: IntPoint
        var tail: [IntPoint]
        var node: SKShapeNode
    }

    enum Ball { case white, gold }

    struct KObstacle {
        var path: [IntPoint]
        var idx: Int
        var node: SKShapeNode
        var lastMoveT: Int
    }

    var player: Entity!
    var echoes: [Entity] = []
    var balls: [IntPoint: Ball] = [:]
    var obstStatic: Set<IntPoint> = []
    var obstKinetic: [KObstacle] = []

    /// 重置所有实体状态
    func reset() {
        echoes.removeAll()
        obstKinetic.removeAll()
        obstStatic.removeAll()
        balls.removeAll()
    }

    /// 判定网格是否可通行
    func passable(_ p: IntPoint, gridW: Int, gridH: Int) -> Bool {
        guard p.x >= 0, p.y >= 0, p.x < gridW, p.y < gridH else { return false }
        if obstStatic.contains(p) { return false }
        for ob in obstKinetic where ob.path[ob.idx] == p { return false }
        return true
    }

    /// 更新尾迹
    func pushTail(_ e: inout Entity) {
        e.tail.insert(e.pos, at: 0)
        if e.tail.count > 6 { _ = e.tail.popLast() }
    }

    /// 尝试移动某个实体，返回是否成功
    func tryMove(_ e: inout Entity, dir: String, gridW: Int, gridH: Int) -> Bool {
        let dmap: [String:(Int,Int)] = ["U":(0,1),"D":(0,-1),"L":(-1,0),"R":(1,0),"W":(0,0)]
        let d = dmap[dir] ?? (0,0)
        let np = IntPoint(x: e.pos.x + d.0, y: e.pos.y + d.1)
        e.prev = e.pos
        if passable(np, gridW: gridW, gridH: gridH) {
            e.pos = np
            pushTail(&e)
            return true
        } else {
            pushTail(&e)
            return false
        }
    }
}

