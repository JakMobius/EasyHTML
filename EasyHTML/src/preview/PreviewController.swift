//
//  PreviewController.swift
//  EasyHTML
//
//  Created by Артем on 13.03.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class NoEditorPreviewController: UIViewController, FileEditor, NotificationHandler {

    static let identifier = "none"

    var editor: Editor!

    func handleMessage(message: EditorMessage, userInfo: Any?) {
        if case .focus = message {
            view.becomeFirstResponder()
        }
    }

    func canHandleMessage(message: EditorMessage) -> Bool {
        if case .focus = message {
            return true
        }
        return false
    }

    func applyConfiguration(config: EditorConfiguration) {

    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    private let topLabel = UILabel()
    private let bottomLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        topLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomLabel.translatesAutoresizingMaskIntoConstraints = false
        topLabel.text = localize("noeditor", .editor)

        topLabel.font = UIFont.systemFont(ofSize: 25)
        topLabel.textAlignment = .center
        bottomLabel.text = localize("noeditorhint", .editor)
        bottomLabel.textColor = .gray
        bottomLabel.font = .systemFont(ofSize: 15)
        bottomLabel.numberOfLines = 0
        bottomLabel.textAlignment = .center
        view.addSubview(topLabel)
        view.addSubview(bottomLabel)

        view.centerXAnchor.constraint(equalTo: topLabel.centerXAnchor).isActive = true
        view.centerYAnchor.constraint(equalTo: topLabel.centerYAnchor, constant: -20).isActive = true
        view.centerXAnchor.constraint(equalTo: bottomLabel.centerXAnchor).isActive = true
        topLabel.bottomAnchor.constraint(equalTo: bottomLabel.topAnchor, constant: -20).isActive = true
        bottomLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -100).isActive = true
        bottomLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 400).isActive = true

        title = localize("editor")

        setupThemeChangedNotificationHandling()

        setupTheme()
    }

    private var appeared = false

    override func viewDidAppear(_ animated: Bool) {
        guard !appeared else {
            return
        }
        navigationItem.rightBarButtonItem = PrimarySplitViewControllerModeButton(window: view.window!)
        appeared = true
    }

    func setupTheme() {
        topLabel.textColor = userPreferences.currentTheme.secondaryTextColor
        view.backgroundColor = userPreferences.currentTheme.background
    }

    func updateTheme() {

        setupTheme()
    }

    @discardableResult static func present(animated: Bool, on switcherView: EditorSwitcherView) -> Editor {
        let editor = Editor()

        editor.controller = self.init()
        editor.present(animated: animated, in: switcherView)
        editor.tabView.isRemovable = false

        return editor
    }

    deinit {
        clearNotificationHandling()
    }
}

internal typealias EditorConfiguration = Dictionary<Editor.ConfigKey, Any>

// TODO: get rid of these

public let EDITOR_UPDATE_FONT_SIZE = 0
public let EDITOR_ENABLE_LOW_ENERGY_MODE = 1
public let EDITOR_DISABLE_LOW_ENERGY_MODE = 2

internal enum EditorMessage: Equatable {
    case save;
    case fileMoved;
    case close;
    case focus;
    case blur;
    case custom(_ code: Int);
}

internal protocol FileEditor {
    func applyConfiguration(config: EditorConfiguration)
    func handleMessage(message: EditorMessage, userInfo: Any?)
    func canHandleMessage(message: EditorMessage) -> Bool

    static var identifier: String { get }
    var editor: Editor! { get set }
}
