//
//  AppDelegate.swift
//  TOAppSettingsMacExample
//
//  Created by Tim Oliver on 23/12/20.
//  Copyright © 2020 Tim Oliver. All rights reserved.
//

import Cocoa

class MacTestSettings: AppSettings {
    @objc dynamic var name = ""
    @objc dynamic var age = 0
    @objc dynamic var birthdate: Date?
    @objc dynamic var grandkids: [String]?
    @objc dynamic var height = 0.0
    @objc dynamic var voiceActors: [String: String]?
    @objc dynamic var portalGunFormula: Data?
    @objc dynamic var portalGunColor: NSColor?
    @objc dynamic var isDrunk = true

    override class func defaultPropertyValues() -> [String: Any] {
        return ["isDrunk": true]
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!

    func demonstrateAppSettings() {

        print("Saving settings")

        // Create an instance with the default configuration
        autoreleasepool {
            let settings = MacTestSettings.default()
            settings.name = "Rick"
            settings.age = 70
            settings.height = 6.1
            settings.birthdate = Date(timeIntervalSince1970: -241290000)
            settings.voiceActors = ["English": "Justin Roiland"]

            print("Settings Saved!")
            // Done! Saved to UserDefaults
        }

        print("Loading Data Back In!")

        // Create a second reference and read the data back in
        let settings = MacTestSettings.default()
        print("Default Settings Name: \(settings.name) Age: \(settings.age)")

        print("Creating second set of data")

        // Create a wholly separate settings object
        autoreleasepool {
            let otherSettings = MacTestSettings(identifier: "Morty")
            otherSettings.name = "Morty"
            otherSettings.age = 14
            otherSettings.height = 4.6

            print("Settings Saved!")
        }

        // Load the data back in
        let otherSettings = MacTestSettings(identifier: "Morty")
        print("Other Settings Name: \(otherSettings.name) Age: \(otherSettings.age)")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        demonstrateAppSettings()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

