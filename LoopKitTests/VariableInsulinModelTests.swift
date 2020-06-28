//
//  VariableInsulinModelTests.swift
//  LoopKitTests
//
//  Created by Michael Pangburn on 6/9/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit


class VariableInsulinModelTests: XCTestCase {
    func testNoVariability() {
        let base = ExponentialInsulinModel(actionDuration: 360, peakActivityTime: 75, delay: 10)
        let model = VariableInsulinModel(base: base, variableEffectTimeline: [])
        let start = Date(timeIntervalSinceReferenceDate: 0)

        for t in stride(from: 0, through: base.actionDuration, by: .minutes(5)) {
            XCTAssertEqual(
                base.percentEffectRemaining(at: t),
                model.percentEffectRemaining(after: DateInterval(start: start, duration: t))
            )
        }
    }

    func testSingleVariablePeriod() {
        let base = ExponentialInsulinModel(actionDuration: .minutes(360), peakActivityTime: .minutes(75), delay: .minutes(10))
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let exerciseStartOffset = TimeInterval(minutes: 30)
        let exercisePeriod = (interval: DateInterval(start: start.addingTimeInterval(exerciseStartOffset), duration: .minutes(30)), rate: 1.5)
        let exerciseEndOffset = exerciseStartOffset + exercisePeriod.interval.duration
        let model = VariableInsulinModel(base: base, variableEffectTimeline: [exercisePeriod])

        // Curve until exercise start should be identical
        for t in stride(from: 0, through: exerciseStartOffset, by: .minutes(5)) {
            XCTAssertEqual(
                base.percentEffectRemaining(at: t),
                model.percentEffectRemaining(after: DateInterval(start: start, duration: t))
            )
        }
    }
}
