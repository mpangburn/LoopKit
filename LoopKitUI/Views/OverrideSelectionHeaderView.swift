//
//  OverrideSelectionHeaderView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 1/27/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


final class OverrideSelectionHeaderView: UICollectionReusableView, IdentifiableClass {
    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet weak var addButton: UIButton! {
        didSet {
            addButton.isHidden = true
            addButton.addTarget(self, action: #selector(add), for: .touchUpInside)
        }
    }

    private var _add: () -> Void = {}

    func onAdd(_ add: @escaping () -> Void) {
        addButton.isHidden = false
        _add = add
    }

    @objc private func add() {
        _add()
    }

    override func prepareForReuse() {
        addButton.isHidden = true
        _add = {}
    }
}
