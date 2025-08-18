#if os(iOS)
import SpriteKit
import UIKit

final class TouchInputController: InputControllerProtocol {
    weak var delegate: InputControllerDelegate?
    private let joystick = JoystickView()
    private var joyActive = false
    private weak var scene: GameScene?

    func configure(scene: GameScene) {
        self.scene = scene
        scene.hud.addChild(joystick)
    }

    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let scene = scene, let t = touches.first else { return }
        joystick.activate(at: t.location(in: scene), in: scene.size)
        joyActive = true
        delegate?.holdChanged(isHolding: false)
        delegate?.startRequested()
    }

    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard joyActive, let scene = scene, let t = touches.first else { return }
        let vec = joystick.update(to: t.location(in: scene))
        let dx = vec.dx, dy = vec.dy
        let dist = hypot(dx, dy)
        let dead: CGFloat = 0.14
        if dist < dead {
            delegate?.directionChanged(to: nil)
            delegate?.holdChanged(isHolding: true)
            return
        }
        delegate?.holdChanged(isHolding: false)
        if abs(dx) > abs(dy) {
            delegate?.directionChanged(to: dx > 0 ? "R" : "L")
        } else {
            delegate?.directionChanged(to: dy > 0 ? "U" : "D")
        }
    }

    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        joystick.deactivate()
        joyActive = false
        delegate?.directionChanged(to: nil)
        delegate?.holdChanged(isHolding: false)
    }
}

extension GameScene {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        (inputController as? TouchInputController)?.touchesBegan(touches, with: event)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        (inputController as? TouchInputController)?.touchesMoved(touches, with: event)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        (inputController as? TouchInputController)?.touchesEnded(touches, with: event)
    }
}
#endif
