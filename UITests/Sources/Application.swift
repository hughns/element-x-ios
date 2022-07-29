//
//  Application.swift
//  UITests
//
//  Created by Stefan Ceriu on 13/04/2022.
//  Copyright © 2022 Element. All rights reserved.
//

import SnapshotTesting
import XCTest

struct Application {
    static func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = ["IS_RUNNING_UI_TESTS": "1"]
        Bundle.elementFallbackLanguage = "en"
        app.launch()
        return app
    }
}

extension XCUIApplication {
    func goToScreenWithIdentifier(_ identifier: UITestScreenIdentifier) {
        let button = buttons[identifier.rawValue]
        let lastLabel = staticTexts["lastItem"]
        
        while !button.isHittable, !lastLabel.isHittable {
            tables.firstMatch.swipeUp()
        }
        
        button.tap()
    }

    /// Assert screenshot for a screen with the given identifier. Does not fail if a screenshot is newly created.
    /// - Parameter identifier: Identifier of the UI test screen
    func assertScreenshot(_ identifier: UITestScreenIdentifier) {
        let failure = verifySnapshot(matching: screenshot().image,
                                     as: .image(precision: 0.98, scale: nil),
                                     named: identifier.rawValue,
                                     testName: testName)

        if let failure = failure,
           !failure.contains("No reference was found on disk."),
           !failure.contains("to test against the newly-recorded snapshot") {
            XCTFail(failure)
        }
    }

    private var testName: String {
        osVersion + "-" + languageCode + "-" + regionCode + "-" + deviceName
    }

    private var deviceName: String {
        UIDevice.current.name
    }

    private var languageCode: String {
        Locale.current.languageCode ?? ""
    }

    private var regionCode: String {
        Locale.current.regionCode ?? ""
    }

    private var osVersion: String {
        UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "-")
    }
}
