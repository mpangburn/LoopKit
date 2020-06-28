//
//  VariableInsulinModel.swift
//  LoopKit
//
//  Created by Michael Pangburn on 6/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation


public struct VariableInsulinModel {
    var base: InsulinModel
    var variableEffectTimeline: [(interval: DateInterval, rate: Double)]

    public init(base: InsulinModel, variableEffectTimeline: [(interval: DateInterval, rate: Double)]) {
        assert(variableEffectTimeline.isSorted(by: { $0.interval.start < $1.interval.start }))
        assert(variableEffectTimeline.adjacentPairs().allSatisfy { $0.interval.end <= $1.interval.start })

        self.base = base
        self.variableEffectTimeline = variableEffectTimeline
    }

    func percentEffectRemaining(after interval: DateInterval) -> Double {
//        1 - percentEffect(over: interval)
        percentEffectRemaining2(after: interval)
    }

    private func percentEffectRemaining2(after interval: DateInterval) -> Double {
        let effectiveTime = effectTimeline(over: interval).reduce(into: 0) { effectiveTime, effect in
            effectiveTime += effect.rate * effect.interval.duration
        }

        print(effectiveTime / .minutes(5))
        return base.percentEffectRemaining(at: effectiveTime)
    }

    private func percentEffect(over interval: DateInterval) -> Double {
        effectTimeline(over: interval).reduce(into: (
            totalEffect: 0 as Double,
            effectiveElapsedTime: 0 as TimeInterval
        )) { (result: inout (totalEffect: Double, effectiveElapsedTime: Double), effect) in
            let effectDuration = effect.interval.end.timeIntervalSince(interval.start) - result.effectiveElapsedTime
            guard effectDuration > 0 else {
                return
            }
            let effectStartTime = result.effectiveElapsedTime
            let scaledEffectDuration = effect.rate * effectDuration
            let effectEndTime = effectStartTime + scaledEffectDuration
            let segment = base.percentEffectRemaining(at: effectStartTime) - base.percentEffectRemaining(at: effectEndTime)
            result.totalEffect += segment
            result.effectiveElapsedTime += scaledEffectDuration
        }
        .totalEffect
        .clamped(to: 0...1)
    }

    private func effectTimeline(over interval: DateInterval) -> [(interval: DateInterval, rate: Double)] {
        var applicableVariableEffectTimeline = Array(
            variableEffectTimeline
                .drop(while: { $0.interval.end < interval.start })
                .prefix(while: { $0.interval.start < interval.end })
        )

        guard !applicableVariableEffectTimeline.isEmpty else {
            return [(interval: interval, rate: 1.0)]
        }

        applicableVariableEffectTimeline[applicableVariableEffectTimeline.startIndex].interval.ceilStart(to: interval.start)
        applicableVariableEffectTimeline[applicableVariableEffectTimeline.lastIndex].interval.floorEnd(to: interval.end)

        if applicableVariableEffectTimeline.first!.interval.start > interval.start {
            let startPeriod = (
                interval: DateInterval(start: interval.start, end: applicableVariableEffectTimeline.first!.interval.start),
                rate: 1.0
            )
            applicableVariableEffectTimeline.insert(startPeriod, at: 0)
        }

        if applicableVariableEffectTimeline.last!.interval.end < interval.end {
            let endPeriod = (
                interval: DateInterval(start: applicableVariableEffectTimeline.last!.interval.end, end: interval.end),
                rate: 1.0
            )
            applicableVariableEffectTimeline.append(endPeriod)
        }

        return [applicableVariableEffectTimeline.first!] + applicableVariableEffectTimeline.adjacentPairs().flatMap { (variableEffect, nextVariableEffect) -> [(interval: DateInterval, rate: Double)] in
            guard variableEffect.interval.end != nextVariableEffect.interval.start else {
                return [nextVariableEffect]
            }

            let normalEffectGap = (interval: DateInterval(start: variableEffect.interval.end, end: nextVariableEffect.interval.start), rate: 1.0)
            return [normalEffectGap, nextVariableEffect]
        }
    }
}

extension BidirectionalCollection {
    /// The last valid index of the collection.
    var lastIndex: Index { index(before: endIndex) }
}

extension DateInterval {
    mutating func ceilStart(to date: Date) {
        assert(date <= end)

        guard start < date else {
            return
        }

        self = DateInterval(start: date, end: end)
    }

    mutating func floorEnd(to date: Date) {
        assert(date >= start)

        guard end > date else {
            return
        }

        self = DateInterval(start: start, end: date)
    }
}
