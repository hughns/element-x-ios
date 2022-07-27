//
//  ApplicationTests.swift
//  IntegrationTests
//
//  Created by Stefan Ceriu on 27/07/2022.
//  Copyright © 2022 Element. All rights reserved.
//

import XCTest

class ApplicationTests: XCTestCase {
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            Application.launch()
        }
    }
}
