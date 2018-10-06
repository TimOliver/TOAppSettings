//
//  AppDelegate.swift
//  TOAppSettingsExample
//
//  Created by Tim Oliver on 29/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

import UIKit

// Create a subclass of `AppSettings` and add all of the
// properties you wish to save.

// Make sure to add `@objc dynamic` to each property.

class MyAppSettings: AppSettings {
    @objc dynamic var name = ""
    @objc dynamic var age = 0
    @objc dynamic var birthdate: Date?
    @objc dynamic var relatives: [String]?
    @objc dynamic var height = 0.0
    @objc dynamic var voiceActors: [String: String]?
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func demonstrateAppSettings() {
        
        print("Saving settings")
        
        // Create an instance with the default configuration
        autoreleasepool {
            let settings = MyAppSettings.default()
            settings.name = "Rick"
            settings.age = 70
            settings.height = 6.1
            settings.birthdate = Date(timeIntervalSince1970: -241290000)
            settings.relatives = ["Morty", "Summer"]
            settings.voiceActors = ["English": "Justin Roiland"]
            
            print("Settings Saved!")
            // Done! Saved to UserDefaults
        }
        
        print("Loading Data Back In!")
        
        // Create a second reference and read the data back in
        let settings = MyAppSettings.default()
        print("Default Settings Name: \(settings.name) Age: \(settings.age)")
        
        print("Creating second set of data")
        
        // Create a wholly separate settings object
        autoreleasepool {
            let otherSettings = MyAppSettings(identifier: "Morty")
            otherSettings.name = "Morty"
            otherSettings.age = 14
            otherSettings.height = 4.6
            otherSettings.relatives = ["Rick", "Summer"]
            
            print("Settings Saved!")
        }
    
        // Load the data back in
        let otherSettings = MyAppSettings(identifier: "Morty")
        print("Other Settings Name: \(otherSettings.name) Age: \(otherSettings.age)")
    }
    
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIViewController()
        window?.rootViewController?.view.backgroundColor = .white
        window?.makeKeyAndVisible()
        
        demonstrateAppSettings()
        
        return true
    }
}

