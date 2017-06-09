//
//  AppDelegate.swift
//  WSAugmentedCameraExample
//
//  Created by Ricardo Pereira on 09/06/2017.
//  Copyright © 2017 Whitesmith. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        window?.rootViewController = CameraViewController()
        return true
    }

}
