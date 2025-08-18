import SpriteKit

protocol InputController: AnyObject {
    var currentDirection: String? { get }
    var isWaiting: Bool { get }
    var onStart: (() -> Void)? { get set }
#if os(iOS)
    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in scene: GameScene)
    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in scene: GameScene)
    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?, in scene: GameScene)
#elseif os(macOS)
    func keyDown(_ event: NSEvent, in scene: GameScene)
    func keyUp(_ event: NSEvent, in scene: GameScene)
#endif
}
