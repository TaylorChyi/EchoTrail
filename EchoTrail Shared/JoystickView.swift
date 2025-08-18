import SpriteKit

/// 虚拟摇杆视图，封装绘制与定位
final class JoystickView: SKNode {
    private let radius: CGFloat = 75
    private let knobRadius: CGFloat = 32
    private let bg: SKShapeNode
    private let knob: SKShapeNode

    override init() {
        bg = SKShapeNode(circleOfRadius: radius)
        knob = SKShapeNode(circleOfRadius: knobRadius)
        super.init()
        isHidden = true
        zPosition = 1000
        setupNodes()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupNodes() {
        bg.fillColor = Theme.accent.withAlphaComponent(0.1)
        bg.strokeColor = Theme.accent.withAlphaComponent(0.3)
        bg.glowWidth = 8
        addChild(bg)
        knob.fillColor = Theme.accent.withAlphaComponent(0.3)
        knob.strokeColor = Theme.accent.withAlphaComponent(0.5)
        knob.glowWidth = 4
        addChild(knob)
    }

    func activate(at point: CGPoint, in size: CGSize) {
        let x = min(max(radius, point.x), size.width - radius)
        let y = min(max(radius, point.y), size.height - radius)
        position = CGPoint(x: x, y: y)
        knob.position = .zero
        isHidden = false
    }

    func update(to point: CGPoint) -> CGVector {
        let dx = point.x - position.x
        let dy = point.y - position.y
        let dist = hypot(dx, dy)
        let maxR = radius - knobRadius
        let r = min(maxR, dist)
        let ang = atan2(dy, dx)
        knob.position = CGPoint(x: cos(ang) * r, y: sin(ang) * r)
        return CGVector(dx: knob.position.x / maxR, dy: knob.position.y / maxR)
    }

    func deactivate() {
        isHidden = true
    }
}
