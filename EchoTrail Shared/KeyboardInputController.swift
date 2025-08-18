#if os(macOS)
import SpriteKit

final class KeyboardInputController: InputController {
    weak var scene: GameScene?
    var currentDirection: String?
    var isWaiting: Bool = false
    var onStart: (() -> Void)?

    init(scene: GameScene) {
        self.scene = scene
    }

    func keyDown(_ event: NSEvent, in scene: GameScene) {
        let map: [UInt16:String] = [126:"U",125:"D",123:"L",124:"R"]
        if let dir = map[event.keyCode] { currentDirection = dir }
        if event.charactersIgnoringModifiers == " " { isWaiting = true }
        onStart?()
    }

    func keyUp(_ event: NSEvent, in scene: GameScene) {
        let map: [UInt16:String] = [126:"U",125:"D",123:"L",124:"R"]
        if map[event.keyCode] != nil { currentDirection = nil }
        if event.charactersIgnoringModifiers == " " { isWaiting = false }
    }
}
#endif
