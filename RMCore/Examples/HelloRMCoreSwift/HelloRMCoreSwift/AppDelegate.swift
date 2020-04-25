//
//  AppDelegate.swift
//  HelloRMCoreSwift
//
//  Created by Foti Dim on 25.04.20.
//  Copyright © 2020 navideck. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var viewController: ViewController?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        // Override point for customization after application launch.
        self.viewController = ViewController(nibName: nil, bundle: nil)
        self.window?.rootViewController = self.viewController
        self.window?.makeKeyAndVisible()
        return true
    }

}

