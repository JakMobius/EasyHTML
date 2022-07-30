//
//  SceneDelegate.swift
//  EasyHTML
//
//  Created by Артем on 05.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit
import SwiftUI

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private var isFirstLaunch: Bool = !isDir(fileName: applicationPath + FileBrowser.filesDir)

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        var fileToOpen: FSNode.File! = nil

        if let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
            self.userActivity = userActivity
            if userActivity.activityType == UserActivity.Types.openFile {
                if let data = userActivity.userInfo?[UserActivity.Key.file] as? Data {
                    fileToOpen = try? JSONDecoder().decode(FSNode.File.self, from: data);
                }
            }
        }

        var initialViewController: UIViewController

        let window = UIWindow(windowScene: scene as! UIWindowScene)

        scene.session.userInfo!["window"] = window

        if BootUtils.isFirstLaunch {
            initialViewController = UIStoryboard(name: "WelcomeScreen", bundle: nil).instantiateViewController(withIdentifier: "main")
        } else {
            let controller = PrimarySplitViewController.instance(for: window)!

            controller.fileToOpen = fileToOpen

            initialViewController = controller
        }

        window.rootViewController = initialViewController
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard let window = (scene as? UIWindowScene)?.windows.first else {
            return
        }

        for editor in Editor.openedEditors {
            if editor.tabView.window == window {
                editor.closeEditor()
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {

        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {

    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let context = URLContexts.first else {
            return
        }
        let url = context.url

        guard let window = scene.session.userInfo!["window"] as? UIWindow else {
            return
        }

        AppDelegate.openURL(url: url, in: window)
    }
}
