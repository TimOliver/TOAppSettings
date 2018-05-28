//
//  TOAppSettingsSwiftTests.swift
//  TOAppSettingsTests
//
//  Created by Tim Oliver on 28/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

import XCTest

class SwiftTestSettings: AppSettings {
    @objc dynamic var name = ""
    @objc dynamic var age = 0
    @objc dynamic var birthdate: Date?
    @objc dynamic var grandkids: [String]?
    @objc dynamic var height = 0.0
    @objc dynamic var voiceActors: [String: String]?
    @objc dynamic var portalGunFormula: Data?
    @objc dynamic var portalGunColor: UIColor?
    @objc dynamic var isDrunk = true
    
    override class func defaultPropertyValues() -> [String: Any] {
        return ["isDrunk": true]
    }
}

class TOAppSettingsSwiftTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        let appDomain = Bundle.main.bundleIdentifier
        UserDefaults.standard.removePersistentDomain(forName: appDomain!)
    }
    
    func testDefaultSettingsWriteAndRead() {
        autoreleasepool {
            let settings = SwiftTestSettings.default()
            settings.name = "Rick"
            settings.age = 70
            settings.grandkids = ["Morty", "Summer"]
            settings.birthdate = Date(timeIntervalSince1970: -241290000)
        }
        
        let settings = SwiftTestSettings.default()
        XCTAssert(settings.name == "Rick")
        XCTAssert(settings.age == 70)
        XCTAssert(settings.grandkids?.first == "Morty")
        XCTAssert(settings.birthdate == Date(timeIntervalSince1970: -241290000))
        XCTAssert(settings.isDrunk == true)
    }
}

