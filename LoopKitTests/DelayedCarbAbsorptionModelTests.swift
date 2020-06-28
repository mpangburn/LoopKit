//
//  DelayedCarbAbsorptionModelTests.swift
//  LoopKitTests
//
//  Created by Michael Pangburn on 6/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit


final class DelayedCarbAbsorptionModelTests: XCTestCase {
    let epsilon = 1e-9

    func testPercentAbsorption() {
        let base = LinearAbsorption()
        let absorptionInterval = DateInterval(start: Date(timeIntervalSinceReferenceDate: 0), duration: .hours(3))
        let workoutInterval = DateInterval(start: absorptionInterval.start.addingTimeInterval(.minutes(30)), duration: .minutes(30))
        let curve = DelayedCarbAbsorptionModel(base: base, zeroAbsorptionPeriods: [workoutInterval])
        XCTAssertEqual(
            curve.percentAbsorption(at: absorptionInterval.start, relativeTo: absorptionInterval),
            0
        )
        XCTAssertEqual(
            curve.percentAbsorption(at: workoutInterval.start, relativeTo: absorptionInterval),
            workoutInterval.duration / absorptionInterval.duration,
            accuracy: epsilon
        )
        XCTAssertEqual(
            curve.percentAbsorption(at: workoutInterval.midpoint, relativeTo: absorptionInterval),
            workoutInterval.duration / absorptionInterval.duration,
            accuracy: epsilon
        )
        XCTAssertEqual(
            curve.percentAbsorption(at: workoutInterval.end, relativeTo: absorptionInterval),
            workoutInterval.duration / absorptionInterval.duration,
            accuracy: epsilon
        )
        XCTAssertEqual(
            curve.percentAbsorption(at: absorptionInterval.midpoint, relativeTo: absorptionInterval),
            (absorptionInterval.duration / 2 - workoutInterval.duration) / absorptionInterval.duration,
            accuracy: epsilon
        )
        XCTAssertEqual(
            curve.percentAbsorption(at: absorptionInterval.end, relativeTo: absorptionInterval),
            (absorptionInterval.duration - workoutInterval.duration) / absorptionInterval.duration,
            accuracy: epsilon
        )
        XCTAssertEqual(
            curve.percentAbsorption(
                at: absorptionInterval.end.addingTimeInterval(workoutInterval.duration),
                relativeTo: absorptionInterval
            ),
            1
        )
    }

    func testPercentRate() {
        let base = LinearAbsorption()
        let absorptionInterval = DateInterval(start: Date(timeIntervalSinceReferenceDate: 0), duration: .hours(3))
        let workoutInterval = DateInterval(start: absorptionInterval.start.addingTimeInterval(.minutes(30)), duration: .minutes(30))
        let curve = DelayedCarbAbsorptionModel(base: base, zeroAbsorptionPeriods: [workoutInterval])
        XCTAssertEqual(
            curve.percentRate(
                at: absorptionInterval.start.addingTimeInterval(.minutes(1)),
                relativeTo: absorptionInterval
            ),
            1
        )
        XCTAssertEqual(
            curve.percentRate(at: workoutInterval.start, relativeTo: absorptionInterval),
            0
        )
        XCTAssertEqual(
            curve.percentRate(at: workoutInterval.midpoint, relativeTo: absorptionInterval),
            0
        )
        XCTAssertEqual(
            curve.percentRate(at: workoutInterval.end, relativeTo: absorptionInterval),
            0
        )
        XCTAssertEqual(
            curve.percentRate(at: absorptionInterval.midpoint, relativeTo: absorptionInterval),
            1
        )
        XCTAssertEqual(
            curve.percentRate(at: absorptionInterval.end, relativeTo: absorptionInterval),
            1
        )
        XCTAssertEqual(
            curve.percentRate(
                at: absorptionInterval.end.addingTimeInterval(workoutInterval.duration),
                relativeTo: absorptionInterval
            ),
            1
        )
    }
}

extension DateInterval {
    var midpoint: Date {
        Date(timeIntervalSinceReferenceDate: (start.timeIntervalSinceReferenceDate + end.timeIntervalSinceReferenceDate) / 2)
    }
}
