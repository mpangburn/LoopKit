//
//  TemporaryScheduleOverrideSettings.swift
//  LoopKit
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit


public struct TemporaryScheduleOverrideSettings: Hashable {
    public enum Role: String, CaseIterable {
        case standard
        case exercise
    }

    private var targetRangeInMgdl: DoubleRange?
    public var insulinNeedsScaleFactor: Double?
    public var role: Role

    public var targetRange: ClosedRange<HKQuantity>? {
        return targetRangeInMgdl.map { $0.quantityRange(for: .milligramsPerDeciliter) }
    }

    public var basalRateMultiplier: Double? {
        return insulinNeedsScaleFactor
    }

    public var insulinSensitivityMultiplier: Double? {
        return insulinNeedsScaleFactor.map { 1.0 / $0 }
    }

    public var carbRatioMultiplier: Double? {
        return insulinNeedsScaleFactor.map { 1.0 / $0 }
    }

    public var effectiveInsulinNeedsScaleFactor: Double {
        return insulinNeedsScaleFactor ?? 1.0
    }

    public init(unit: HKUnit, targetRange: DoubleRange?, insulinNeedsScaleFactor: Double? = nil, role: Role = .standard) {
        self.targetRangeInMgdl = targetRange?.quantityRange(for: unit).doubleRange(for: .milligramsPerDeciliter)
        self.insulinNeedsScaleFactor = insulinNeedsScaleFactor
        self.role = role
    }
}

extension TemporaryScheduleOverrideSettings: RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum Key {
        static let targetRange = "targetRange"
        static let insulinNeedsScaleFactor = "insulinNeedsScaleFactor"
        static let role = "role"
        static let version = "version"
    }

    public init?(rawValue: RawValue) {
        if let targetRangeRawValue = rawValue[Key.targetRange] as? DoubleRange.RawValue,
            let targetRange = DoubleRange(rawValue: targetRangeRawValue) {
            self.targetRangeInMgdl = targetRange
        }
        self.role = (rawValue[Key.role] as? Role.RawValue).flatMap(Role.init(rawValue:)) ?? .standard
        self.insulinNeedsScaleFactor = rawValue[Key.insulinNeedsScaleFactor] as? Double

        let version = rawValue[Key.version] as? Int ?? 0

        // Do not allow target ranges from versions < 1, as there was no unit convention at that point.
        if version < 1 && targetRange != nil {
            return nil
        }
    }

    public var rawValue: RawValue {
        var raw: RawValue = [Key.role: role.rawValue]

        if let targetRange = targetRangeInMgdl {
            raw[Key.targetRange] = targetRange.rawValue
        }

        if let insulinNeedsScaleFactor = insulinNeedsScaleFactor {
            raw[Key.insulinNeedsScaleFactor] = insulinNeedsScaleFactor
        }

        raw[Key.version] = 1

        return raw
    }
}
