//
//  GameViewController.swift
//  EchoTrail macOS
//
//  Created by 齐天乐 on 2025/8/18.
//

import Cocoa
import SpriteKit

class GameViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let skView = view as! SKView
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.ignoresSiblingOrder = true

        let scene = GameScene(size: skView.bounds.size)
        let controller = KeyboardInputController(scene: scene)
        scene.input = controller
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)

        view.window?.makeFirstResponder(skView) // 使键盘事件进入场景
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        (view as? SKView)?.scene?.size = view.bounds.size
    }
}
