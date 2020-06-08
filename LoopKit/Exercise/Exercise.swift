//
//  Exercise.swift
//  LoopKit
//
//  Created by Michael Pangburn on 6/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation


struct DelayedCarbAbsorptionModel {
    var base: CarbAbsorptionComputable
    var zeroAbsorptionPeriods: [DateInterval]

    init(base: CarbAbsorptionComputable, zeroAbsorptionPeriods: [DateInterval]) {
        assert(zeroAbsorptionPeriods.isSorted(by: { $0.start < $1.start }))
        assert(zeroAbsorptionPeriods.adjacentPairs().allSatisfy { $0.end <= $1.start })

        self.base = base
        self.zeroAbsorptionPeriods = zeroAbsorptionPeriods
    }

    func percentAbsorption(at date: Date, relativeTo absorptionInterval: DateInterval) -> Double {
        let delay = accumulatedDelay(over: DateInterval(start: absorptionInterval.start, end: date))
        let delayedPercentTime = date.fractionThrough(absorptionInterval) - delay / absorptionInterval.duration
        return base.percentAbsorptionAtPercentTime(delayedPercentTime)
    }

    func percentRate(at date: Date, relativeTo absorptionInterval: DateInterval) -> Double {
        guard isAbsorbing(at: date) else {
            return 0
        }

        let delay = accumulatedDelay(over: DateInterval(start: absorptionInterval.start, end: date))
        let delayedPercentTime = date.fractionThrough(absorptionInterval) - delay / absorptionInterval.duration
        return base.percentRateAtPercentTime(forPercentTime: delayedPercentTime)
    }

    func absorbedCarbs(of total: Double, at date: Date, relativeTo absorptionInterval: DateInterval) -> Double {
        total * percentAbsorption(at: date, relativeTo: absorptionInterval)
    }

    func unabsorbedCarbs(of total: Double, at date: Date, relativeTo absorptionInterval: DateInterval) -> Double {
        total - absorbedCarbs(of: total, at: date, relativeTo: absorptionInterval)
    }

    func absorptionTime(forPercentAbsorption percentAbsorption: Double, at date: Date, relativeTo absorptionInterval: DateInterval) -> TimeInterval {
        let time = date.timeIntervalSince(absorptionInterval.start)
        return base.absorptionTime(forPercentAbsorption: percentAbsorption, atTime: time) + accumulatedDelay(over: absorptionInterval)
    }

    func timeToAbsorb(forPercentAbsorbed percentAbsorption: Double, absorptionTime: TimeInterval) -> TimeInterval {
        // Because of zero-absorption periods, this function is no longer one-to-one
        // TODO: Account for this in estimating time remaining in CarbStatusBuilder
        return base.timeToAbsorb(forPercentAbsorbed: percentAbsorption, absorptionTime: absorptionTime)
    }

    private func accumulatedDelay(over interval: DateInterval) -> TimeInterval {
        let clampedOffsets = zeroAbsorptionPeriods.lazy.map { zeroAbsorptionInterval in
            (end: min(interval.end, zeroAbsorptionInterval.end).timeIntervalSinceReferenceDate,
             start: max(interval.start, zeroAbsorptionInterval.start).timeIntervalSinceReferenceDate)
        }

        return clampedOffsets
            .filter(>)
            .map(-)
            .reduce(0, +)

    }

    private func isAbsorbing(at date: Date) -> Bool {
        !zeroAbsorptionPeriods.contains(where: { $0.contains(date) })
    }
}

extension Date {
    func fractionThrough(_ interval: DateInterval) -> Double {
        (timeIntervalSinceReferenceDate - interval.start.timeIntervalSinceReferenceDate) / interval.duration
    }
}

extension DateInterval {
    func extended(by duration: TimeInterval) -> DateInterval {
        DateInterval(start: start, end: end.addingTimeInterval(duration))
    }
}

extension Collection {
    func isSorted(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows -> Bool {
        try adjacentPairs().allSatisfy { try !areInIncreasingOrder($1, $0) }
    }
}
