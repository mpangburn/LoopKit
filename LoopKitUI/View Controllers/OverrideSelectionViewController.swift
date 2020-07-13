//
//  OverrideSelectionViewController.swift
//  Loop
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit


public protocol OverrideSelectionViewControllerDelegate: AnyObject {
    func overrideSelectionViewController(_ vc: OverrideSelectionViewController, didUpdatePresets presets: [TemporaryScheduleOverridePreset])
    func overrideSelectionViewController(_ vc: OverrideSelectionViewController, didConfirmOverride override: TemporaryScheduleOverride)
    func overrideSelectionViewController(_ vc: OverrideSelectionViewController, didCancelOverride override: TemporaryScheduleOverride)
}

public final class OverrideSelectionViewController: UICollectionViewController, IdentifiableClass {

    public var glucoseUnit: HKUnit!

    public var scheduledOverride: TemporaryScheduleOverride?

    public func setPresets(_ presets: [TemporaryScheduleOverridePreset]) {
        presetsByRole = presets.reduce(into: [:]) { result, preset in
            result[preset.settings.role, default: []].append(preset)
        }
    }

    private var presetsByRole: [TemporaryScheduleOverrideSettings.Role: [TemporaryScheduleOverridePreset]] = [:] {
        didSet {
            delegate?.overrideSelectionViewController(self, didUpdatePresets: presets)
        }
    }

    private var presets: [TemporaryScheduleOverridePreset] {
        TemporaryScheduleOverrideSettings.Role.allCases.flatMap { presetsByRole[$0] ?? [] }
    }

    public weak var delegate: OverrideSelectionViewControllerDelegate?

    private lazy var editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(beginEditing))
    private lazy var doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(endEditing))
    private lazy var cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = LocalizedString("Temporary Override", comment: "The title for the override selection screen")
        collectionView?.backgroundColor = .groupTableViewBackground
        navigationItem.rightBarButtonItem = editButton
        navigationItem.leftBarButtonItem = cancelButton
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    enum Section: Int, CaseIterable {
        case scheduledOverride = 0
        case exercisePresets
        case standardPresets
    }

    private var sections: [Section] {
        var sections = Section.allCases
        if scheduledOverride == nil {
            sections.remove(.scheduledOverride)
        }
        return sections
    }

    private func section(for sectionIndex: Int) -> Section {
        return sections[sectionIndex]
    }

    private enum CellContent {
        case scheduledOverride(TemporaryScheduleOverride)
        case preset(TemporaryScheduleOverridePreset)
        case customOverride(role: TemporaryScheduleOverrideSettings.Role)
    }

    private func cellContent(for indexPath: IndexPath) -> CellContent {
        switch section(for: indexPath.section) {
        case .scheduledOverride:
            guard let scheduledOverride = scheduledOverride else {
                preconditionFailure("`sections` must contain `.scheduledOverride`")
            }
            return .scheduledOverride(scheduledOverride)
        case .exercisePresets:
            if let exercisePresets = presetsByRole[.exercise], exercisePresets.indices.contains(indexPath.row) {
                return .preset(exercisePresets[indexPath.row])
            } else {
                return .customOverride(role: .exercise)
            }
        case .standardPresets:
            if let standardPresets = presetsByRole[.standard], standardPresets.indices.contains(indexPath.row) {
                return .preset(standardPresets[indexPath.row])
            } else {
                return .customOverride(role: .standard)
            }
        }
    }

    private var indexPathsOfCustomOverride: [IndexPath] {
        [
            IndexPath(row: presetsByRole[.exercise, default: []].endIndex - 1, section: sections.firstIndex(of: .exercisePresets)!),
            IndexPath(row: presetsByRole[.standard, default: []].endIndex - 1, section: sections.firstIndex(of: .standardPresets)!),
        ]
    }

    public override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch self.section(for: section) {
        case .scheduledOverride:
            return 1
        case .exercisePresets:
            // +1 for custom override
            return (presetsByRole[.exercise]?.count ?? 0) + 1
        case .standardPresets:
            // +1 for custom override
            return (presetsByRole[.standard]?.count ?? 0) + 1
        }
    }

    public override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: OverrideSelectionHeaderView.className, for: indexPath) as! OverrideSelectionHeaderView
            switch section(for: indexPath.section) {
            case .scheduledOverride:
                header.titleLabel.text = LocalizedString("SCHEDULED OVERRIDE", comment: "The section header text for a scheduled override")
            case .exercisePresets:
                header.titleLabel.text = LocalizedString("EXERCISE PRESETS", comment: "The section header text override presets")
                header.onAdd { [unowned self] in
                    self.addNewPreset(role: .exercise)
                }
            case .standardPresets:
                header.titleLabel.text = LocalizedString("OTHER PRESETS", comment: "The section header text override presets")
                header.onAdd { [unowned self] in
                    self.addNewPreset(role: .standard)
                }
            }
            return header
        default:
            fatalError("Unexpected supplementary element kind \(kind)")
        }
    }

    private lazy var quantityFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.setPreferredNumberFormatter(for: glucoseUnit)
        return quantityFormatter
    }()

    private lazy var glucoseNumberFormatter = quantityFormatter.numberFormatter

    private lazy var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let customSymbol = "⋯"
        let customName = LocalizedString("Custom", comment: "The text for a custom override")

        switch cellContent(for: indexPath) {
        case .scheduledOverride(let override):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OverridePresetCollectionViewCell.className, for: indexPath) as! OverridePresetCollectionViewCell
            cell.delegate = self
            if case .preset(let preset) = override.context {
                cell.symbolLabel.text = preset.symbol
                cell.nameLabel.text = preset.name
            } else {
                cell.symbolLabel.text = customSymbol
                cell.nameLabel.text = customName
            }

            cell.startTimeLabel.text = DateFormatter.localizedString(from: override.startDate, dateStyle: .none, timeStyle: .short)
            configure(cell, with: override.settings, duration: override.duration)
            cell.scheduleButton.isHidden = true
            if isEditingPresets {
                cell.applyOverlayToFade(animated: false)
            }

            return cell
        case .preset(let preset):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OverridePresetCollectionViewCell.className, for: indexPath) as! OverridePresetCollectionViewCell
            cell.delegate = self
            cell.symbolLabel.text = preset.symbol
            cell.nameLabel.text = preset.name
            configure(cell, with: preset.settings, duration: preset.duration)
            if isEditingPresets {
                cell.configureForEditing(animated: false)
            }

            return cell
        case .customOverride:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomOverrideCollectionViewCell.className, for: indexPath) as! CustomOverrideCollectionViewCell
            cell.titleLabel.text = customName
            if isEditingPresets {
                cell.applyOverlayToFade(animated: false)
            }

            return cell
        }
    }

    private func configure(_ cell: OverridePresetCollectionViewCell, with settings: TemporaryScheduleOverrideSettings, duration: TemporaryScheduleOverride.Duration) {
        if let targetRange = settings.targetRange {
            cell.targetRangeLabel.text = makeTargetRangeText(from: targetRange)
        } else {
            cell.targetRangeLabel.isHidden = true
        }

        if let insulinNeedsScaleFactor = settings.insulinNeedsScaleFactor {
            cell.insulinNeedsBar.progress = insulinNeedsScaleFactor
        } else {
            cell.insulinNeedsBar.isHidden = true
        }

        switch duration {
        case .finite(let interval):
            cell.durationLabel.text = durationFormatter.string(from: interval)
        case .indefinite:
            cell.durationLabel.text = "∞"
        }
    }

    private func makeTargetRangeText(from targetRange: ClosedRange<HKQuantity>) -> String {
        guard
            let minTarget = glucoseNumberFormatter.string(from: targetRange.lowerBound.doubleValue(for: glucoseUnit)),
            let maxTarget = glucoseNumberFormatter.string(from: targetRange.upperBound.doubleValue(for: glucoseUnit))
        else {
            return ""
        }

        return String(format: LocalizedString("%1$@ – %2$@ %3$@", comment: "The format for a glucose target range. (1: min target)(2: max target)(3: glucose unit)"), minTarget, maxTarget, quantityFormatter.string(from: glucoseUnit))
    }

    public override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditingPresets {
            switch cellContent(for: indexPath) {
            case .scheduledOverride, .customOverride:
                break
            case .preset(let preset):
                let editVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
                editVC.inputMode = .editPreset(preset)
                editVC.delegate = self
                show(editVC, sender: collectionView.cellForItem(at: indexPath))
            }
        } else {
            switch cellContent(for: indexPath) {
            case .scheduledOverride(let override):
                let editOverrideVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
                editOverrideVC.inputMode = .editOverride(override)
                editOverrideVC.customDismissalMode = .dismissModal
                editOverrideVC.delegate = self
                show(editOverrideVC, sender: collectionView.cellForItem(at: indexPath))
            case .preset(let preset):
                let override = preset.createOverride(enactTrigger: .local)
                delegate?.overrideSelectionViewController(self, didConfirmOverride: override)
                dismiss(animated: true)
            case .customOverride(role: let role):
                let customOverrideVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
                customOverrideVC.inputMode = .customOverride(role: role)
                customOverrideVC.delegate = self
                show(customOverrideVC, sender: collectionView.cellForItem(at: indexPath))
            }
        }
    }

    private func addNewPreset(role: TemporaryScheduleOverrideSettings.Role) {
        let addVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
        addVC.inputMode = .newPreset(role: role)
        addVC.delegate = self

        let navigationWrapper = UINavigationController(rootViewController: addVC)
        present(navigationWrapper, animated: true)
    }

    private var isEditingPresets = false {
        didSet {
            cancelButton.isEnabled = !isEditingPresets
        }
    }

    @objc private func beginEditing() {
        isEditingPresets = true
        navigationItem.setRightBarButton(doneButton, animated: true)
        configureCellsForEditingChanged()

        if let scheduledOverrideSection = sections.firstIndex(of: .scheduledOverride) {
            let scheduledOverrideIndexPath = IndexPath(row: 0, section: scheduledOverrideSection)
            guard let scheduledOverrideCell = collectionView.cellForItem(at: scheduledOverrideIndexPath) as? OverridePresetCollectionViewCell else {
                return
            }

            scheduledOverrideCell.applyOverlayToFade(animated: true)
        }

        indexPathsOfCustomOverride
            .compactMap { collectionView.cellForItem(at: $0) as? CustomOverrideCollectionViewCell }
            .forEach { $0.applyOverlayToFade(animated: true) }
    }

    @objc private func endEditing() {
        isEditingPresets = false
        navigationItem.setRightBarButton(editButton, animated: true)
        configureCellsForEditingChanged()

        if let scheduledOverrideSection = sections.firstIndex(of: .scheduledOverride) {
            let scheduledOverrideIndexPath = IndexPath(row: 0, section: scheduledOverrideSection)
            guard let scheduledOverrideCell = collectionView.cellForItem(at: scheduledOverrideIndexPath) as? OverridePresetCollectionViewCell else {
                return
            }

            scheduledOverrideCell.removeOverlay(animated: true)
        }

        indexPathsOfCustomOverride
            .compactMap { collectionView.cellForItem(at: $0) as? CustomOverrideCollectionViewCell }
            .forEach { $0.removeOverlay(animated: true) }
    }

    private func configureCellsForEditingChanged() {
        for indexPath in collectionView.indexPathsForVisibleItems where section(for: indexPath.section) != .scheduledOverride {
            if let cell = collectionView.cellForItem(at: indexPath) as? OverridePresetCollectionViewCell {
                if isEditingPresets {
                    cell.configureForEditing(animated: true)
                } else {
                    cell.configureForStandard(animated: true)
                }
            }
        }
    }

    public override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        if !isEditingPresets {
            return true
        }

        switch cellContent(for: indexPath) {
        case .scheduledOverride, .customOverride:
            return false
        case .preset:
            return true
        }
    }

    public override func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        isEditingPresets
            && indexPath.section != sections.firstIndex(of: .scheduledOverride)
            && !indexPathsOfCustomOverride.contains(indexPath)

    }

    public override func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        var movedPreset: TemporaryScheduleOverridePreset
        switch section(for: sourceIndexPath.section) {
        case .scheduledOverride:
            assertionFailure("Cannot move item from `scheduledOverride` section")
            return
        case .exercisePresets:
            movedPreset = presetsByRole[.exercise]!.remove(at: sourceIndexPath.row)
        case .standardPresets:
            movedPreset = presetsByRole[.standard]!.remove(at: sourceIndexPath.row)
        }

        switch section(for: destinationIndexPath.section) {
        case .scheduledOverride:
            assertionFailure("Cannot move item to `scheduledOverride` section")
            return
        case .exercisePresets:
            movedPreset.settings.role = .exercise
            presetsByRole[.exercise]!.insert(movedPreset, at: destinationIndexPath.row)
        case .standardPresets:
            movedPreset.settings.role = .standard
            presetsByRole[.standard]!.insert(movedPreset, at: destinationIndexPath.row)
        }
    }

    public override func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        guard proposedIndexPath.section != sections.firstIndex(of: .scheduledOverride) else {
            return originalIndexPath
        }

        return indexPathsOfCustomOverride.contains(originalIndexPath)
            ? originalIndexPath
            : proposedIndexPath

    }
}

extension OverrideSelectionViewController: UICollectionViewDelegateFlowLayout {
    private var sectionInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 12, bottom: 12, right: 12)
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        .zero
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let paddingSpace = sectionInsets.left * 2
        let width = view.frame.width - paddingSpace
        let height: CGFloat
        switch cellContent(for: indexPath) {
        case .scheduledOverride, .preset:
            height = 76
        case .customOverride:
            height = 52
        }

        return CGSize(width: width, height: height)
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        return sectionInsets
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return sectionInsets.left
    }
}

extension OverrideSelectionViewController: AddEditOverrideTableViewControllerDelegate {
    public func addEditOverrideTableViewController(_ vc: AddEditOverrideTableViewController, didSavePreset preset: TemporaryScheduleOverridePreset) {
        if let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first {
            switch section(for: selectedIndexPath.section) {
            case .scheduledOverride:
                assertionFailure("Unreachable: no presets available for editing in `scheduledOverride` section")
            case .exercisePresets:
                presetsByRole[.exercise]![selectedIndexPath.row] = preset
            case .standardPresets:
                presetsByRole[.standard]![selectedIndexPath.row] = preset
            }
            collectionView.reloadItems(at: [selectedIndexPath])
            collectionView.deselectItem(at: selectedIndexPath, animated: true)
        } else {
            let newIndexPath: IndexPath
            switch preset.settings.role {
            case .exercise:
                presetsByRole[.exercise, default: []].append(preset)
                newIndexPath = IndexPath(row: presetsByRole[.exercise]!.endIndex - 1, section: sections.firstIndex(of: .exercisePresets)!)
            case .standard:
                presetsByRole[.standard, default: []].append(preset)
                newIndexPath = IndexPath(row: presetsByRole[.standard]!.endIndex - 1, section: sections.firstIndex(of: .standardPresets)!)
            }
            collectionView.insertItems(at: [newIndexPath])
            delegate?.overrideSelectionViewController(self, didUpdatePresets: presets)
        }
    }

    public func addEditOverrideTableViewController(_ vc: AddEditOverrideTableViewController, didSaveOverride override: TemporaryScheduleOverride) {
        delegate?.overrideSelectionViewController(self, didConfirmOverride: override)
    }

    public func addEditOverrideTableViewController(_ vc: AddEditOverrideTableViewController, didCancelOverride override: TemporaryScheduleOverride) {
        delegate?.overrideSelectionViewController(self, didCancelOverride: override)
    }
}

extension OverrideSelectionViewController: OverridePresetCollectionViewCellDelegate {
    func overridePresetCollectionViewCellDidScheduleOverride(_ cell: OverridePresetCollectionViewCell) {
        guard
            let indexPath = collectionView.indexPath(for: cell),
            case .preset(let preset) = cellContent(for: indexPath)
        else {
            return
        }

        let customizePresetVC = AddEditOverrideTableViewController(glucoseUnit: glucoseUnit)
        customizePresetVC.inputMode = .customizePresetOverride(preset)
        customizePresetVC.delegate = self
        show(customizePresetVC, sender: nil)
    }

    func overridePresetCollectionViewCellDidPerformFirstDeletionStep(_ cell: OverridePresetCollectionViewCell) {
        for case let visibleCell as OverridePresetCollectionViewCell in collectionView.visibleCells
            where visibleCell !== cell && visibleCell.isShowingFinalDeleteConfirmation
        {
            visibleCell.configureForEditing(animated: true)
        }
    }

    func overridePresetCollectionViewCellDidDeletePreset(_ cell: OverridePresetCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }

        switch section(for: indexPath.section) {
        case .scheduledOverride:
            assertionFailure("No preset to delete in `scheduledOverride` section")
        case .exercisePresets:
            presetsByRole[.exercise]!.remove(at: indexPath.row)
        case .standardPresets:
            presetsByRole[.standard]!.remove(at: indexPath.row)
        }
        collectionView.deleteItems(at: [indexPath])
    }
}

private extension Array where Element: Equatable {
    mutating func remove(_ element: Element) {
        if let index = self.firstIndex(of: element) {
            remove(at: index)
        }
    }
}
