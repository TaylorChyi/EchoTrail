import SpriteKit

final class GameScene: SKScene, GameCoreDelegate {
    private let worldNode = SKNode()
    private let hudNode = SKNode()
    private var hudManager: HUDManager!
    private let gameOverOverlay = GameOverOverlay()
    var inputController: InputControllerProtocol!
    private let core = GameCore()

    override func didMove(to view: SKView) {
        backgroundColor = Theme.background
        addChild(worldNode)
        addChild(hudNode)
        hudManager = HUDManager(sceneSize: size)
        hudNode.addChild(hudManager)
        core.delegate = self
        core.configure()
        #if os(iOS)
        inputController = TouchInputController()
        #elseif os(macOS)
        inputController = KeyboardInputController()
        #endif
        inputController.delegate = core
        inputController.configure(scene: self)
    }

    override func update(_ currentTime: TimeInterval) {
        core.update(currentTime: currentTime)
    }

    // MARK: - GameCoreDelegate
    var world: SKNode { worldNode }

    func cellSize() -> CGSize {
        CGSize(width: size.width/Double(GameConfig.gridWidth+2),
               height: size.height/Double(GameConfig.gridHeight+2))
    }

    func pointFor(_ p: IntPoint) -> CGPoint {
        let cs = cellSize()
        return CGPoint(x: (Double(p.x)+1.5)*cs.width,
                       y: (Double(p.y)+1.5)*cs.height)
    }

    func updateHUD(score: Int, multiplier: Double, time: Double, echoPeak: Int) {
        hudManager.update(score: score, multiplier: multiplier, time: time, echoPeak: echoPeak)
    }

    func showGameOver(message: String) {
        gameOverOverlay.show(message: message, in: self)
    }

    func hideGameOver() {
        gameOverOverlay.hide()
    }
}
