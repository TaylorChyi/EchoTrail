import SpriteKit

protocol InputControllerDelegate: AnyObject {
    func directionChanged(to direction: String?)
    func holdChanged(isHolding: Bool)
    func startRequested()
}

protocol InputControllerProtocol: AnyObject {
    var delegate: InputControllerDelegate? { get set }
    func configure(scene: GameScene)
}
