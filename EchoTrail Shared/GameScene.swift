import SpriteKit

/// 仅负责 Scene 生命周期、节点添加与输入转发
final class GameScene: SKScene, GameCoreDelegate {
    // 渲染容器与 UI
    private let world = SKNode()
    private let hud = SKNode()
    private var hudManager: HUDManager!
    private let gameOverOverlay = GameOverOverlay()

    // 虚拟摇杆（iOS 使用）
    private let joystick = JoystickView()
    private var joyActive = false

    // 核心逻辑
    private var core: GameCore!

    // MARK: - 生命周期
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.04, green: 0.06, blue: 0.08, alpha: 1)
        addChild(world)
        addChild(hud)
        hudManager = HUDManager(sceneSize: size)
        hud.addChild(hudManager)
        hud.addChild(joystick)
        core = GameCore(delegate: self, sceneSize: size)
        core.start()
    }

    override func update(_ currentTime: TimeInterval) {
        core.update(currentTime: currentTime)
    }

    // MARK: - GameCoreDelegate
    var worldNode: SKNode { world }
    func updateHUD(score: Int, multiplier: Double, time: Double, echoPeak: Int) {
        hudManager.update(score: score, multiplier: multiplier, time: time, echoPeak: echoPeak)
    }
    func showGameOver(message: String) { gameOverOverlay.show(message: message, in: self) }
    func hideGameOver() { gameOverOverlay.hide() }
    func spawnParticle(at p: IntPoint, color: SKColor) {
        let cs = core.cellSize()
        let pt = core.pointFor(p)
        for _ in 0..<10 {
            let r = SKShapeNode(rectOf: CGSize(width: 4, height: 4), cornerRadius: 1)
            r.fillColor = color; r.strokeColor = color; r.position = pt; r.zPosition = 10
            world.addChild(r)
            let dx = CGFloat.random(in: -cs.width*0.1...cs.width*0.1)
            let dy = CGFloat.random(in: -cs.height*0.1...cs.height*0.1)
            r.run(.sequence([.group([.moveBy(x: dx, y: dy, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        }
    }

    // MARK: - 输入
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        joystick.activate(at: t.location(in: self), in: size)
        joyActive = true
        core.setHold(false)
        core.startPlayingIfNeeded()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard joyActive, let t = touches.first else { return }
        let vec = joystick.update(to: t.location(in: self))
        let dx = vec.dx, dy = vec.dy
        let dist = hypot(dx, dy)
        let dead: CGFloat = 0.14
        if dist < dead { core.updateDirection(nil); core.setHold(true); return }
        core.setHold(false)
        if abs(dx) > abs(dy) { core.updateDirection(dx > 0 ? "R" : "L") } else { core.updateDirection(dy > 0 ? "U" : "D") }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        joystick.deactivate(); joyActive = false; core.updateDirection(nil); core.setHold(false)
    }
    #endif

    #if os(macOS)
    override func keyDown(with event: NSEvent) {
        let map: [UInt16:String] = [126:"U",125:"D",123:"L",124:"R"]
        if let dir = map[event.keyCode] { core.updateDirection(dir) }
        if event.charactersIgnoringModifiers == " " { core.setHold(true) }
        core.startPlayingIfNeeded()
    }
    override func keyUp(with event: NSEvent) {
        let map: [UInt16:String] = [126:"U",125:"D",123:"L",124:"R"]
        if map[event.keyCode] != nil { core.updateDirection(nil) }
        if event.charactersIgnoringModifiers == " " { core.setHold(false) }
    }
    #endif
}

