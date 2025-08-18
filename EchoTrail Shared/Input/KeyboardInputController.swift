#if os(macOS)
import SpriteKit

final class KeyboardInputController: InputControllerProtocol {
    weak var delegate: InputControllerDelegate?

    func configure(scene: GameScene) {}

    func keyDown(with event: NSEvent) {
        let map: [UInt16:String] = [126:"U",125:"D",123:"L",124:"R"]
        if let dir = map[event.keyCode] {
            delegate?.directionChanged(to: dir)
        }
        if event.charactersIgnoringModifiers == " " {
            delegate?.holdChanged(isHolding: true)
        }
        delegate?.startRequested()
    }

    func keyUp(with event: NSEvent) {
        let map: [UInt16:String] = [126:"U",125:"D",123:"L",124:"R"]
        if map[event.keyCode] != nil {
            delegate?.directionChanged(to: nil)
        }
        if event.charactersIgnoringModifiers == " " {
            delegate?.holdChanged(isHolding: false)
        }
    }
}

extension GameScene {
    override func keyDown(with event: NSEvent) {
        (inputController as? KeyboardInputController)?.keyDown(with: event)
    }
    override func keyUp(with event: NSEvent) {
        (inputController as? KeyboardInputController)?.keyUp(with: event)
    }
}
#endif
