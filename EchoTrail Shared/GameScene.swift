//
//  GameScene.swift
//  EchoTrail Shared
//
//  Created by 齐天乐 on 2025/8/18.
//

import SpriteKit

final class GameScene: SKScene {
    private let world = SKNode()
    private let hud = SKNode()
    private var hudManager: HUDManager!
    private let gameOverOverlay = GameOverOverlay()
    private var inputController: InputControllerProtocol!
    private var core: GameCore!

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.04, green: 0.06, blue: 0.08, alpha: 1)
        addChild(world)
        addChild(hud)
        hudManager = HUDManager(sceneSize: size)
        hud.addChild(hudManager)
        #if os(iOS)
        inputController = TouchInputController()
        #elseif os(macOS)
        inputController = KeyboardInputController()
        #endif
        inputController.delegate = self
        inputController.configure(scene: self)
        core = GameCore(sceneSize: size, delegate: self)
        core.buildWorld()
        core.enterIdle()
    }

    override func update(_ currentTime: TimeInterval) {
        core.update(currentTime: currentTime)
    }
}

extension GameScene: GameCoreDelegate {
    func resetWorld() {
        gameOverOverlay.hide()
        world.removeAllChildren()
    }

    func addNodeToWorld(_ node: SKNode) {
        world.addChild(node)
    }

    func updateHUD(score: Int, multiplier: Double, time: Double, echoPeak: Int) {
        hudManager.update(score: score, multiplier: multiplier, time: time, echoPeak: echoPeak)
    }

    func showGameOver(message: String) {
        gameOverOverlay.show(message: message, in: self)
    }

    func audioNode() -> SKNode { self }
}

extension GameScene: InputControllerDelegate {
    func directionChanged(to direction: String?) {
        core.directionChanged(to: direction)
    }

    func holdChanged(isHolding: Bool) {
        core.holdChanged(isHolding: isHolding)
    }

    func startRequested() {
        core.startRequested()
    }
}

