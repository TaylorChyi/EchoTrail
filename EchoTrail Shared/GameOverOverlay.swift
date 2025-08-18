import SpriteKit

/// “游戏结束”覆盖层，含背景与文本
final class GameOverOverlay: SKNode {
    private let background: SKShapeNode
    private let label: SKLabelNode
    private let padding: CGFloat = 20
    private let corner: CGFloat = 16

    override init() {
        background = SKShapeNode()
        label = SKLabelNode(fontNamed: UIConfig.HUD.fontName)
        super.init()
        label.fontSize = UIConfig.HUD.fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(background)
        addChild(label)
        zPosition = 2000
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(message: String, in scene: SKScene) {
        label.text = message
        let width = label.frame.width + padding * 2
        let height = label.frame.height + padding * 2
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        background.path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
        background.fillColor = Theme.accent.withAlphaComponent(0.2)
        background.strokeColor = Theme.accent.withAlphaComponent(0.4)
        background.lineWidth = 2
        background.glowWidth = 4
        position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        if parent == nil { scene.addChild(self) }
    }

    func hide() { removeFromParent() }
}
