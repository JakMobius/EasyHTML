//
//  ImagePreviewController.swift
//  EasyHTML
//
//  Created by Артем on 25.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

class ImagePreviewController: UIViewController, UIScrollViewDelegate, FileEditor, NotificationHandler {

    static let identifier = "image"

    var editor: Editor!

    final func handleMessage(message: EditorMessage, userInfo: Any?) {
        if case .close = message {
            ioManager.stopActivity()
        } else if case .fileMoved = message {
            title = (userInfo as! URL).lastPathComponent
        } else if case .focus = message {
            view.becomeFirstResponder()
        } else if case .blur = message {
            view.resignFirstResponder()
        }
    }

    final func canHandleMessage(message: EditorMessage) -> Bool {
        if case .close = message {
            return true
        }
        if case .fileMoved = message {
            return true
        }
        if case .focus = message {
            return true
        }
        if case .blur = message {
            return true
        }
        return false
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    func applyConfiguration(config: EditorConfiguration) {
        if let ioManager = config[.ioManager] as? Editor.IOManager {
            self.ioManager = ioManager
        }
        if let editor = config[.editor] as? Editor {
            self.editor = editor
        }
    }

    private var messageManager: EditorMessageViewManager!

    internal var ioManager = Editor.IOManager()

    private var scrollView = UIScrollView()
    private var loadingInfoView: LoadingInfoView! = LoadingInfoView()
    private var file: FSNode.File!
    private var imageView: UIImageView!

    private func recalculateImageViewSize() {

        let size = scrollView.frame.size

        if let image = imageView.image {
            let width = image.size.width
            let height = image.size.height

            let viewWidth = size.width
            let viewHeight = size.height
            var coefficient: CGFloat = 1.0

            if width > viewWidth {
                coefficient = width / viewWidth
            }
            if height > viewHeight * coefficient {
                coefficient = height / viewHeight
            }

            coefficient /= scrollView.zoomScale

            imageView.frame = CGRect(origin: .zero, size: CGSize(width: width / coefficient, height: height / coefficient))
        }
    }

    private func recalculateOffsets() {

        let imageWidth = imageView.frame.size.width
        let imageHeight = imageView.frame.size.height

        if imageHeight <= scrollView.frame.height {
            let shiftHeight = scrollView.frame.height / 2.0 - imageHeight / 2.0
            scrollView.contentInset.top = shiftHeight
        } else {
            scrollView.contentInset.top = 0
        }
        if imageWidth <= scrollView.frame.width {
            let shiftWidth = scrollView.frame.width / 2.0 - imageWidth / 2.0
            scrollView.contentInset.left = shiftWidth
        } else {
            scrollView.contentInset.left = 0
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        recalculateOffsets()
    }

    private func loadingErrorHandler(error: Error?) {
        let message = error?.localizedDescription ?? localize("downloaderror")

        messageManager.newWarning(message: localize("downloadknownerror") + "\n" + message)
                .applyingStyle(style: .error)
                .withCloseable(false)
                .withButton(EditorWarning.Button(title: localize("tryagain"), target: self, action: #selector(loadImage)))
                .present()
    }

    private func decodingErrorHandler() {
        let message = localize("imagedecodingerror")

        messageManager.newWarning(message: message)
                .applyingStyle(style: .error)
                .withCloseable(false)
                .present()
    }

    @objc func loadImage() {

        messageManager.reset()

        loadingInfoView.fade()

        imageView = UIImageView(frame: .zero)

        let loadingDescription = localize("loadingstep_downloading", .editor)

        loadingInfoView.infoLabel.text = loadingDescription.replacingOccurrences(of: "#", with: "0")

        ioManager.readFileAt(url: file.url, completion: { (data, error) in

            if let data = data {
                self.loadingInfoView.infoLabel.text = localize("loadingstep_loadingfile", .editor)
                DispatchQueue(label: "easyhtml.imagedecodingtask").async {

                    var image: UIImage! = nil

                    if (self.file.url.pathExtension == "gif") {
                        image = UIImage.gif(data: data)
                    } else {
                        image = UIImage(data: data)
                    }

                    DispatchQueue.main.async {
                        self.loadingInfoView.hide()
                        if image == nil {
                            self.decodingErrorHandler()
                            return
                        }

                        self.imageView.alpha = 0
                        self.imageView.image = image

                        self.scrollView.addSubview(self.imageView)

                        UIView.animate(withDuration: 0.2, animations: {
                            self.imageView.alpha = 1.0
                        })

                        self.scrollView.delegate = self
                        self.scrollView.minimumZoomScale = 1.0
                        self.scrollView.maximumZoomScale = 5.0

                        self.scrollView.contentInset.right = 0
                        self.scrollView.contentInset.bottom = 0

                        self.recalculateImageViewSize()
                        self.recalculateOffsets()

                        self.loadingInfoView.removeFromSuperview()
                        self.loadingInfoView = nil
                    }
                }
            } else {
                self.loadingInfoView.hide()
                self.loadingErrorHandler(error: error)
            }
        }, progress: {
            progress in
            self.loadingInfoView.infoLabel.text = loadingDescription.replacingOccurrences(of: "#", with: String(Int(progress.fractionCompleted * 100)))
        })
    }

    func updateTheme() {

        view.backgroundColor = userPreferences.currentTheme.background
    }

    override func viewDidAppear(_ animated: Bool) {
        if navigationItem.rightBarButtonItem == nil {
            navigationItem.rightBarButtonItem = PrimarySplitViewControllerModeButton(window: view.window!)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let file = editor.file else {
            fatalError("Expected file")
        }

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)

        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scrollView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        scrollView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        view.addSubview(loadingInfoView)

        loadingInfoView.fade()

        edgesForExtendedLayout = []
        messageManager = EditorMessageViewManager(parent: self)

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }

        self.file = file

        title = file.name

        loadImage()

        updateTheme()

        setupThemeChangedNotificationHandling()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        recalculateImageViewSize()
        recalculateOffsets()
        messageManager?.recalculatePositions()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    deinit {
        clearNotificationHandling()
    }
}
