import SpriteKit

/// 负责分数、倍数、时间与回声峰值的统一 UI 管理
final class HUDManager: SKNode {
    private enum Layout {
        static let fontName = Theme.Font.primary
        static let fontSize = Theme.Font.hudSize
        static let lineHeight = Theme.HUD.lineHeight
        static let padding = Theme.HUD.padding
        static let corner = Theme.HUD.corner
        static let width = Theme.HUD.width
    }

    private let background: SKShapeNode
    private let scoreLabel = SKLabelNode(fontNamed: Layout.fontName)
    private let multLabel = SKLabelNode(fontNamed: Layout.fontName)
    private let timeLabel = SKLabelNode(fontNamed: Layout.fontName)
    private let echoLabel = SKLabelNode(fontNamed: Layout.fontName)

    init(sceneSize: CGSize) {
        let height = Layout.padding * 2 + Layout.lineHeight * 4
        background = SKShapeNode(rectOf: CGSize(width: Layout.width, height: height), cornerRadius: Layout.corner)
        super.init()
        background.fillColor = Theme.accent.withAlphaComponent(0.15)
        background.strokeColor = Theme.accent.withAlphaComponent(0.4)
        background.lineWidth = 2
        background.glowWidth = 4
        addChild(background)
        position = CGPoint(x: Layout.padding + Layout.width / 2,
                           y: sceneSize.height - Layout.padding - height / 2)
        setupLabels(height: height)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLabels(height: CGFloat) {
        let labels = [scoreLabel, multLabel, timeLabel, echoLabel]
        for (i, label) in labels.enumerated() {
            label.fontSize = Layout.fontSize
            label.fontColor = .white
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            let y = height / 2 - Layout.padding - CGFloat(i) * Layout.lineHeight
            label.position = CGPoint(x: -Layout.width / 2 + Layout.padding, y: y)
            addChild(label)
        }
    }

    func update(score: Int, multiplier: Double, time: Double, echoPeak: Int) {
        scoreLabel.text = "分数 \(score)"
        multLabel.text = String(format: "倍数 %.1f×", multiplier)
        timeLabel.text = String(format: "时间 %.1fs", time)
        echoLabel.text = "回声 \(echoPeak)"
    }
}
