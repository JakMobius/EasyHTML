//
//  WelcomeViewController.swift
//  EasyHTML
//
//  Created by Артем on 22.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

class WelcomeViewController: UIViewController {

    @IBOutlet var button: UIButton!
    @IBOutlet var welcomeLabelBottom: UILabel!
    @IBOutlet var welcomeLabelTop: UILabel!
    @IBOutlet var logoImage: UIImageView!

    private var buttonColor = UIColor.darkGray

    private var step = -1
    private var controllerToBePresented: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        let image = UIImage.getImageFilledWithColor(
                color: UIColor(red: 0.45, green: 0.66, blue: 0.84, alpha: 1.0))

        button.setBackgroundImage(image, for: .normal)
        button.backgroundColor = UIColor(red: 0.36, green: 0.61, blue: 0.81, alpha: 1.0)
        button.cornerRadius = 5.0
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(buttonAction(_:)), for: .touchUpInside)
        button.setTitle(localize(/*# -tcanalyzerignore #*/ "welcome_btntxt1"), for: .normal)

        welcomeLabelTop.text = localize("welcometitle")
        welcomeLabelBottom.text = localize("welcometext")

        UIView.animate(withDuration: 0.7, delay: 0.3, options: .curveEaseInOut, animations: {
            self.logoImage.transform = CGAffineTransform(translationX: 0, y: -150)
        })
        UIView.animate(withDuration: 1.0, delay: 0.6, options: .curveEaseOut, animations: {
            self.welcomeLabelTop.alpha = 1.0
        })
        UIView.animate(withDuration: 1.0, delay: 0.9, options: .curveEaseOut, animations: {
            self.welcomeLabelBottom.alpha = 1.0
        })
        UIView.animate(withDuration: 1.0, delay: 1.2, options: .curveEaseOut, animations: {
            self.button.alpha = 1.0
        })
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    private static let count = 3

    func install() {
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: applicationPath + FileBrowser.filesDir), withIntermediateDirectories: false, attributes: nil)

        try? readBundleFile(name: "startexample", ext: "html")?.write(toFile: applicationPath + FileBrowser.filesDir + "/example.html", atomically: false, encoding: .utf8)
    }

    @objc func buttonAction(_ sender: UIButton) {
        if (step == WelcomeViewController.count - 1) {

            // Create all necessary files and perform transition to the main application view

            install()
            
            let window = view.window!
            let viewController = PrimarySplitViewController.instance(for: view)!
            
            viewController.view.frame = window.rootViewController!.view.frame
            viewController.view.layoutIfNeeded()

            UIView.transition(with: window, duration: 1.0, options: [.allowAnimatedContent,     .layoutSubviews, .transitionFlipFromLeft], animations: {
                            window.rootViewController = viewController
            })

            return;
        }

        sender.isEnabled = false

        if step == -1 {
            button.setTextWithFadeAnimation(text: localize(/*# -tcanalyzerignore #*/ "welcome_btntxt2"), duration: 0.3)
        } else if (step == WelcomeViewController.count - 2) {
            button.setTextWithFadeAnimation(text: localize(/*# -tcanalyzerignore #*/ "welcome_btntxt3"), duration: 0.3)
        }

        UIView.animate(withDuration: 0.3, animations: {
            self.welcomeLabelBottom.alpha = 0.0
            self.welcomeLabelTop.alpha = 0.0
        }, completion: {
            _ in
            self.welcomeLabelTop.text = localize(/*# -tcanalyzerignore #*/ "welcometitle\(self.step)")
            self.welcomeLabelBottom.text = localize(/*# -tcanalyzerignore #*/ "welcometext\(self.step)")
            self.welcomeLabelBottom.sizeToFit()
            self.welcomeLabelBottom.transform = CGAffineTransform(translationX: 0, y: -10)

            UIView.animate(withDuration: 0.3, animations: {

                self.welcomeLabelBottom.alpha = 1.0
                self.welcomeLabelTop.alpha = 1.0
                self.welcomeLabelBottom.transform = CGAffineTransform.identity
            }, completion: {
                _ in
                sender.isEnabled = true
            })
        })

        step += 1
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
