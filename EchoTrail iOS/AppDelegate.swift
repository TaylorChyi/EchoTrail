//
//  AppDelegate.swift
//  EchoTrail iOS
//
//  Created by 齐天乐 on 2025/8/18.
//

import UIKit
import AVFoundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let session = AVAudioSession.sharedInstance()
        // 环境音：遵守静音键，可与其他应用混音；如需强制出声改为 .playback（Playback（媒体播放））
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        UIApplication.shared.isIdleTimerDisabled = true
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
