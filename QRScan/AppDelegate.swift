//
//  AppDelegate.swift
//  QRScan
//
//  Created by 成璐飞 on 2016/10/8.
//  Copyright © 2016年 成璐飞. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.windows[0].makeKeyAndOrderFront(self)
        return true
    }

}

