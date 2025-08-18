#if os(iOS)
import SpriteKit

final class TouchInputController: InputController {
    weak var scene: GameScene?
    var currentDirection: String?
    var isWaiting: Bool = false
    var onStart: (() -> Void)?

    private var joyActive = false
    private var joyOrigin = CGPoint.zero

    init(scene: GameScene) {
        self.scene = scene
    }

    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in scene: GameScene) {
        guard let t = touches.first else { return }
        joyOrigin = t.location(in: scene)
        scene.joyBg.position = joyOrigin
        scene.joyKnob.position = joyOrigin
        scene.joyBg.isHidden = false
        scene.joyKnob.isHidden = false
        joyActive = true
        isWaiting = false
        onStart?()
    }

    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in scene: GameScene) {
        guard joyActive, let t = touches.first else { return }
        let p = t.location(in: scene)
        let dx = p.x - joyOrigin.x
        let dy = p.y - joyOrigin.y
        let dist = hypot(dx, dy)
        let ang = atan2(dy, dx)
        let maxR: CGFloat = 50
        let r = min(maxR, dist)
        scene.joyKnob.position = CGPoint(x: joyOrigin.x + cos(ang) * r, y: joyOrigin.y + sin(ang) * r)
        let dead: CGFloat = 14
        if dist < dead {
            currentDirection = nil
            isWaiting = true
            return
        }
        isWaiting = false
        if abs(dx) > abs(dy) {
            currentDirection = dx > 0 ? "R" : "L"
        } else {
            currentDirection = dy > 0 ? "U" : "D"
        }
    }

    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?, in scene: GameScene) {
        joyActive = false
        scene.joyBg.isHidden = true
        scene.joyKnob.isHidden = true
        currentDirection = nil
        isWaiting = false
    }
}
#endif
