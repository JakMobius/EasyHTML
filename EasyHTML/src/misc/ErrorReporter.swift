//
//  ErrorReporter.swift
//  EasyHTML
//
//  Created by Артем on 14.03.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit
import MessageUI

class ErrorReporter: NSObject, MFMailComposeViewControllerDelegate {

    private var completion: (() -> ())? = nil;
    private static var presentedReporter: ErrorReporter?
    private var fileURL: URL!

    internal func reportFile(fileURL: URL, text: String, subject: String, mime: String, fileName: String, parent: UIViewController, completion: (() -> ())? = nil) -> Bool {
        if (ErrorReporter.presentedReporter != nil) {
            print("[EasyHTML] Trying to open two ErrorReporters at the same time")
            return false
        }
        self.fileURL = fileURL
        ErrorReporter.presentedReporter = self
        self.completion = completion
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.setToRecipients(["jakmobius@gmail.com"])
            mail.setSubject(subject)
            mail.setMessageBody(text, isHTML: true)

            if let data = try? Data(contentsOf: fileURL) {
                mail.addAttachmentData(data, mimeType: mime, fileName: fileName)
            }

            mail.mailComposeDelegate = self

            parent.present(mail, animated: true);

            return true
        }

        return false
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        ErrorReporter.presentedReporter = nil

        controller.dismiss(animated: true, completion: nil)
        completion?();

        try? FileManager.default.removeItem(at: fileURL)
    }
}
