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

        for t in stride(from: 0, through: base.delay + base.actionDuration, by: .minutes(5)) {
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

        for t in stride(from: exerciseStartOffset, through: base.delay + base.actionDuration, by: .minutes(5)) {
            let completedExerciseTime = min(t - exerciseStartOffset, exercisePeriod.interval.duration)
            let postExerciseTime = max(t - exerciseEndOffset, 0)
            let effectiveAbsorptionTimeDuringExercise = exerciseStartOffset + completedExerciseTime * exercisePeriod.rate + postExerciseTime
            XCTAssertEqual(
                model.percentEffectRemaining(after: DateInterval(start: start, duration: t)),
                base.percentEffectRemaining(at: effectiveAbsorptionTimeDuringExercise)
            )
        }
    }

    func testMultipleVariablePeriods() {
        let base = ExponentialInsulinModel(actionDuration: .minutes(360), peakActivityTime: .minutes(75), delay: .minutes(10))
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let firstExerciseStartOffset = TimeInterval(minutes: 30)
        let firstExercisePeriod = (interval: DateInterval(start: start.addingTimeInterval(firstExerciseStartOffset), duration: .minutes(30)), rate: 1.5)
        let firstExerciseEndOffset = firstExerciseStartOffset + firstExercisePeriod.interval.duration

        let secondExerciseStartOffset = TimeInterval(minutes: 90)
        let secondExercisePeriod = (interval: DateInterval(start: start.addingTimeInterval(secondExerciseStartOffset), duration: .minutes(45)), rate: 1.2)
        let secondExerciseEndOffset = secondExerciseStartOffset + secondExercisePeriod.interval.duration

        let model = VariableInsulinModel(base: base, variableEffectTimeline: [firstExercisePeriod, secondExercisePeriod])

        // Curve until exercise start should be identical
        for t in stride(from: 0, through: firstExerciseStartOffset, by: .minutes(5)) {
            XCTAssertEqual(
                base.percentEffectRemaining(at: t),
                model.percentEffectRemaining(after: DateInterval(start: start, duration: t))
            )
        }

        for t in stride(from: firstExerciseStartOffset, through: firstExerciseEndOffset, by: .minutes(5)) {
            let completedExerciseTime = min(t - firstExerciseStartOffset, firstExercisePeriod.interval.duration)
            let postExerciseTime = max(t - firstExerciseEndOffset, 0)
            let effectiveAbsorptionTimeDuringExercise = firstExerciseStartOffset + completedExerciseTime * firstExercisePeriod.rate + postExerciseTime

            XCTAssertEqual(
                model.percentEffectRemaining(after: DateInterval(start: start, duration: t)),
                base.percentEffectRemaining(at: effectiveAbsorptionTimeDuringExercise)
            )
        }

        for t in stride(from: firstExerciseEndOffset, through: secondExerciseStartOffset, by: .minutes(5)) {
            let completedExerciseTime = firstExercisePeriod.interval.duration
            let postExerciseTime = t - firstExerciseEndOffset
            let effectiveAbsorptionTimeDuringExercise = firstExerciseStartOffset + completedExerciseTime * firstExercisePeriod.rate + postExerciseTime

            XCTAssertEqual(
                model.percentEffectRemaining(after: DateInterval(start: start, duration: t)),
                base.percentEffectRemaining(at: effectiveAbsorptionTimeDuringExercise)
            )
        }

        for t in stride(from: secondExerciseStartOffset, through: base.delay + base.actionDuration, by: .minutes(5)) {
            let completedFirstExerciseTime = firstExercisePeriod.interval.duration
            let intraExerciseTime = secondExerciseStartOffset - firstExerciseEndOffset
            let completedSecondExerciseTime = min(t - secondExerciseStartOffset, secondExercisePeriod.interval.duration)
            let postSecondExerciseTime = max(t - secondExerciseEndOffset, 0)
            let effectiveAbsorptionTimeDuringExercise = firstExerciseStartOffset
                + completedFirstExerciseTime * firstExercisePeriod.rate
                + intraExerciseTime
                + completedSecondExerciseTime * secondExercisePeriod.rate
                + postSecondExerciseTime

            XCTAssertEqual(
                model.percentEffectRemaining(after: DateInterval(start: start, duration: t)),
                base.percentEffectRemaining(at: effectiveAbsorptionTimeDuringExercise)
            )
        }
    }
}
