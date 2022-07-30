//
//  Extensions.swift
//  EasyHTML
//
//  Created by Артем on 11.10.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import Foundation
import UIKit
import AudioToolbox

extension UIImage {
    func maskWithColor(color: UIColor) -> UIImage? {
        let maskImage = cgImage!

        let width = size.width * scale
        let height = size.height * scale
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!

        context.clip(to: bounds, mask: maskImage)
        context.setFillColor(color.cgColor)
        context.fill(bounds)

        if let cgImage = context.makeImage() {
            let coloredImage = UIImage(cgImage: cgImage)
            return coloredImage
        } else {
            return nil
        }
    }

    func invertedImage() -> UIImage? {
        guard let cgImage = cgImage else {
            return nil
        }
        let ciImage = CoreImage.CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorInvert") else {
            return nil
        }
        filter.setDefaults()
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        let context = CIContext(options: nil)
        guard let outputImage = filter.outputImage else {
            return nil
        }
        guard let outputImageCopy = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return UIImage(cgImage: outputImageCopy)
    }

    static func getImageFilledWithColor(color: UIColor, width: CGFloat = 1, height: CGFloat = 1) -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        UIGraphicsGetCurrentContext()!.setFillColor(color.cgColor)
        UIGraphicsGetCurrentContext()!.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let colorImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return colorImage!
    }

    func resized(to size: CGSize, opaque: Bool = false) -> UIImage {

        let widthRatio = size.width / self.size.width
        let heightRatio = size.height / self.size.height

        var width: CGFloat
        var height: CGFloat

        if (widthRatio > heightRatio) {
            width = self.size.width * heightRatio
            height = self.size.height * heightRatio
        } else {
            width = self.size.width * widthRatio
            height = self.size.height * widthRatio
        }

        if #available(iOS 10.0, *) {
            let renderFormat = UIGraphicsImageRendererFormat.default()
            renderFormat.opaque = opaque
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: renderFormat)
            return renderer.image {
                (context) in
                self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        } else {
            UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), opaque, 0)
            self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            let image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return image
        }
    }
}

extension UITextField {
    func setLeftPaddingPoints(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: frame.size.height))
        leftView = paddingView
        leftViewMode = .always
    }

    func setRightPaddingPoints(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: frame.size.height))
        rightView = paddingView
        rightViewMode = .always
    }
}

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

extension UIButton {
    internal func setTextWithFadeAnimation(text: String, duration: TimeInterval = 0.1, completion: ((Bool) -> ())? = nil, forControlState: UIControl.State = .normal) {
        let duration = duration / 2
        UIView.animate(withDuration: duration, animations: {
            self.alpha = 0
        }, completion: {
            _ in
            self.setTitle(text, for: forControlState)
            UIView.animate(withDuration: duration, animations: {
                self.alpha = 1
            }, completion: completion)
        })
    }
}

extension NSNotification.Name {
    internal static var TCFileListUpdated = NSNotification.Name.init("TCFileListUpdated")
    internal static var TCThemeChanged = NSNotification.Name.init("TCThemeChanged")
    internal static var TCFileMetadataChanged = NSNotification.Name.init("TCFileMetadataChanged")
    internal static var TCUpdateExpanderMenu = NSNotification.Name.init("TCUpdateExpanderMenu")
    internal static var TCPreferencesOpened = NSNotification.Name.init("TCPreferencesOpened")
    internal static var TCPreferencesClosed = NSNotification.Name.init("TCPreferencesClosed")
}

extension UILabel {
    internal func setTextWithFadeAnimation(text: String, duration: TimeInterval = 0.5, completion: ((Bool) -> ())? = nil) {
        let duration = duration / 2
        UIView.animate(withDuration: duration, animations: {
            self.alpha = 0
        }, completion: {
            _ in
            self.text = text
            UIView.animate(withDuration: duration, animations: {
                self.alpha = 1
            }, completion: completion)
        })
    }
}

extension BootUtils {
    static func readDeviceInfo() {
        _modelType = {
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)

            let identifier = machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else {
                    return identifier
                }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }
            return identifier
        }()

        if _modelType.hasPrefix("iPhone") {

            let modelWithoutPrefix = String(_modelType.suffix(_modelType.count - 6))

            if let iPhoneVersion = Version(parsing: modelWithoutPrefix.replacingOccurrences(of: ",", with: ".")) {

                /*var devicesWithEyebrow = [
                 iPhone10,1 : iPhone 8
                 iPhone10,2 : iPhone 8 Plus
                 -> iPhone10,3 : iPhone X Global
                 iPhone10,4 : iPhone 8
                 iPhone10,5 : iPhone 8 Plus
                 -> iPhone10,6 : iPhone X GSM
                 -> iPhone11,2 : iPhone XS
                 -> iPhone11,4 : iPhone XS Max
                 -> iPhone11,6 : iPhone XS Max Global
                 -> iPhone11,8 : iPhone XR
                 ]*/

                _isIPhone6S = modelWithoutPrefix == "8,1" || modelWithoutPrefix == "8,2"

                if iPhoneVersion.majorVersion == 10 {
                    _hasAnEyebrow = iPhoneVersion.minorVersion == 3 || iPhoneVersion.minorVersion == 6
                } else {
                    _hasAnEyebrow = iPhoneVersion.majorVersion == 11
                }
            } else {
                _isIPhone6S = false
                _hasAnEyebrow = false
            }
        } else {
            _isIPhone6S = false
            _hasAnEyebrow = false
        }
    }
}

fileprivate var _modelType: String = "unknown"

fileprivate var _isIPhone6S: Bool = false

fileprivate var _hasAnEyebrow: Bool = false

fileprivate var _isHapticFeedbackSupported: Bool {
    if #available(iOS 10.0, *) {
        if (_isIPhone6S) {
            return true
        }
        let model = _modelType
        if (model.hasPrefix("iPhone")) {
            if let commaIndex = model.firstIndex(of: ",") {
                let model = model.prefix(upTo: commaIndex)
                if let modelNumber = Int(model.suffix(model.count - 6)) {
                    return modelNumber >= 8
                }
            }
            return false
        } /* else if(model.hasPrefix("iPad")) {
             if let commaIndex = model.index(of: ",") {
                 model = model.prefix(upTo: commaIndex)
         
                 if let modelNumber = Int(model.suffix(model.count - 4)) {
                    return modelNumber >= 5
                 }
            }
        } else if(model.hasPrefix("iPod")) {
            if let commaIndex = model.index(of: ",") {
                let model = model.prefix(upTo: commaIndex)
                if let modelNumber = Int(model.suffix(model.count - 4)) {
                return modelNumber >= 5
                }
            }
            return false
        }*/

        return false
    }

    return false
}

extension UIDevice {


    var hasAnEyebrow: Bool {
        _hasAnEyebrow
    }

    var isIPhone6S: Bool {
        _isIPhone6S
    }

    var modelType: String {
        _modelType
    }

//    1000    new-mail.caf              MailReceived
//    1001    mail-sent.caf             MailSent
//    1002    Voicemail.caf             VoicemailReceived
//    1003    ReceivedMessage.caf       SMSReceived
//    1004    SentMessage.caf           SMSSent
//    1005    alarm.caf                 CalendarAlert
//    1006    low_power.caf             LowPower
//    1007    sms-received1.caf         SMSReceived_Alert
//    1008    sms-received2.caf         SMSReceived_Alert
//    1009    sms-received3.caf         SMSReceived_Alert
//    1010    sms-received4.caf         SMSReceived_Alert
//    1011    -                         SMSReceived_Vibrate
//    1012    sms-received1.caf         SMSReceived_Alert
//    1013    sms-received5.caf         SMSReceived_Alert
//    1014    sms-received6.caf         SMSReceived_Alert
//    1015    Voicemail.caf    -
//    1016    tweet_sent.caf            SMSSent
//    1020    Anticipate.caf            SMSReceived_Alert
//    1021    Bloom.caf                 SMSReceived_Alert
//    1022    Calypso.caf               SMSReceived_Alert
//    1023    Choo_Choo.caf             SMSReceived_Alert
//    1024    Descent.caf               SMSReceived_Alert
//    1025    Fanfare.caf               SMSReceived_Alert
//    1026    Ladder.caf                SMSReceived_Alert
//    1027    Minuet.caf                SMSReceived_Alert
//    1028    News_Flash.caf            SMSReceived_Alert
//    1029    Noir.caf                  SMSReceived_Alert
//    1030    Sherwood_Forest.caf       SMSReceived_Alert
//    1031    Spell.caf                 SMSReceived_Alert
//    1032    Suspense.caf              SMSReceived_Alert
//    1033    Telegraph.caf             SMSReceived_Alert
//    1034    Tiptoes.caf               SMSReceived_Alert
//    1035    Typewriters.caf           SMSReceived_Alert
//    1036    Update.caf                SMSReceived_Alert
//    1050    ussd.caf                  USSDAlert
//    1051    SIMToolkitCallDropped.caf     SIMToolkitTone
//    1052    SIMToolkitGeneralBeep.caf     SIMToolkitTone
//    1053    SIMToolkitNegativeACK.caf     SIMToolkitTone
//    1054    SIMToolkitPositiveACK.caf     SIMToolkitTone
//    1055    SIMToolkitSMS.caf             SIMToolkitTone
//    1057    Tink.caf                      PINKeyPressed
//    1070    ct-busy.caf                   AudioToneBusy
//    1071    ct-congestion.caf             AudioToneCongestion
//    1072    ct-path-ack.caf               AudioTonePathAcknowledge
//    1073    ct-error.caf                  AudioToneError
//    1074    ct-call-waiting.caf           AudioToneCallWaiting
//    1075    ct-keytone2.caf               AudioToneKey2
//    1100    lock.caf                      ScreenLocked
//    1101    unlock.caf                    ScreenUnlocked
//    1102    -                             FailedUnlock
//    1103    Tink.caf                      KeyPressed
//    1104    Tock.caf                      KeyPressed
//    1105    Tock.caf                      KeyPressed
//    1106    beep-beep.caf                 ConnectedToPower
//    1107    RingerChanged.caf             RingerSwitchIndication
//    1108    photoShutter.caf              CameraShutter
//    1109    shake.caf                     ShakeToShuffle
//    1110    jbl_begin.caf                 JBL_Begin
//    1111    jbl_confirm.caf               JBL_Confirm
//    1112    jbl_cancel.caf                JBL_Cancel
//    1113    begin_record.caf              BeginRecording
//    1114    end_record.caf                EndRecording
//    1115    jbl_ambiguous.caf             JBL_Ambiguous
//    1116    jbl_no_match.caf              JBL_NoMatch
//    1117    begin_video_record.caf        BeginVideoRecording
//    1118    end_video_record.caf          EndVideoRecording
//    1150    vc~invitation-accepted.caf    VCInvitationAccepted
//    1151    vc~ringing.caf                VCRinging
//    1152    vc~ended.caf                  VCEnded
//    1153    ct-call-waiting.caf           VCCallWaiting
//    1154    vc~ringing.caf                VCCallUpgrade
//    1200    dtmf-0.caf                    TouchTone
//    1201    dtmf-1.caf                    TouchTone
//    1202    dtmf-2.caf                    TouchTone
//    1203    dtmf-3.caf                    TouchTone
//    1204    dtmf-4.caf                    TouchTone
//    1205    dtmf-5.caf                    TouchTone
//    1206    dtmf-6.caf                    TouchTone
//    1207    dtmf-7.caf                    TouchTone
//    1208    dtmf-8.caf                    TouchTone
//    1209    dtmf-9.caf                    TouchTone
//    1210    dtmf-star.caf                 TouchTone
//    1211    dtmf-pound.caf                TouchTone
//    1254    long_low_short_high.caf       Headset_StartCall
//    1255    short_double_high.caf         Headset_Redial
//    1256    short_low_high.caf            Headset_AnswerCall
//    1257    short_double_low.caf          Headset_EndCall
//    1258    short_double_low.caf          Headset_CallWaitingActions
//    1259    middle_9_short_double_low.caf Headset_TransitionEnd
//    1300    Voicemail.caf                 SystemSoundPreview
//    1301    ReceivedMessage.caf           SystemSoundPreview
//    1302    new-mail.caf                  SystemSoundPreview
//    1303    mail-sent.caf                 SystemSoundPreview
//    1304    alarm.caf                     SystemSoundPreview
//    1305    lock.caf                      SystemSoundPreview
//    1306    Tock.caf                      KeyPressClickPreview
//    1307    sms-received1.caf             SMSReceived_Selection
//    1308    sms-received2.caf             SMSReceived_Selection
//    1309    sms-received3.caf             SMSReceived_Selection
//    1310    sms-received4.caf             SMSReceived_Selection
//    1311    -                             SMSReceived_Vibrate
//    1312    sms-received1.caf             SMSReceived_Selection
//    1313    sms-received5.caf             SMSReceived_Selection
//    1314    sms-received6.caf             SMSReceived_Selection
//    1315    Voicemail.caf                 SystemSoundPreview
//    1320    Anticipate.caf                SMSReceived_Selection
//    1321    Bloom.caf                     SMSReceived_Selection
//    1322    Calypso.caf                   SMSReceived_Selection
//    1323    Choo_Choo.caf                 SMSReceived_Selection
//    1324    Descent.caf                   SMSReceived_Selection
//    1325    Fanfare.caf                   SMSReceived_Selection
//    1326    Ladder.caf                    SMSReceived_Selection
//    1327    Minuet.caf                    SMSReceived_Selection
//    1328    News_Flash.caf                SMSReceived_Selection
//    1329    Noir.caf                      SMSReceived_Selection
//    1330    Sherwood_Forest.caf           SMSReceived_Selection
//    1331    Spell.caf                     SMSReceived_Selection
//    1332    Suspense.caf                  SMSReceived_Selection
//    1333    Telegraph.caf                 SMSReceived_Selection
//    1334    Tiptoes.caf                   SMSReceived_Selection
//    1335    Typewriters.caf               SMSReceived_Selection
//    1336    Update.caf                    SMSReceived_Selection
//    1350    -                             RingerVibeChanged
//    1351    -                             SilentVibeChanged
//    4095    -                             Vibrate
//    1519    -                             Actuate `Peek` feedback (weak boom)
//    1520    -                             Actuate `Pop` feedback (strong boom)
//    1521    -                             Actuate `Nope` feedback (series of three weak boom)

    func produceSimpleHapticFeedback(level: UInt32 = 1519) -> Bool {

        if (userPreferences.hapticFeedbackEnabled) {
            if (isIPhone6S) {
                AudioServicesPlaySystemSound(level)

                return false
            }
            return true
        }
        return false
    }

    var isHapticFeedbackSupported: Bool {
        _isHapticFeedbackSupported

    }

    var systemSize: Int64? {
        guard let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String),
              let totalSize = (systemAttributes[.systemSize] as? NSNumber)?.int64Value
        else {
            return nil
        }

        return totalSize
    }

    var systemFreeSize: Int64? {
        guard let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String),
              let freeSize = (systemAttributes[.systemFreeSize] as? NSNumber)?.int64Value
        else {
            return nil
        }

        return freeSize
    }
}

extension FileManager {
    func clearTempDirectory() {

        func clearFolder(path: String) {
            do {
                let contents = try contentsOfDirectory(atPath: path)
                contents.forEach { file in
                    try? removeItem(atPath: path + file)
                }
            } catch {
                print(error)
            }
        }

        clearFolder(path: NSTemporaryDirectory())
        clearFolder(path: applicationPath + "/inbox")
    }
}

extension UIScrollView {

    func scrollRectToCenter(_ rect: CGRect, animated: Bool = true, completion: (() -> ())! = nil) {

        var x = rect.midX - bounds.width / 2
        var y = rect.midY - bounds.height / 2

        // TODO: Indents are not taken into account here

        y = max(min(y, contentSize.height - bounds.height), 0)
        x = max(min(x, contentSize.width - bounds.width), 0)

        if contentOffset.x == x && contentOffset.y == y {
            completion?()
            return
        }

        UIView.animate(withDuration: 0.35, animations: {

            self.contentOffset = CGPoint(
                    x: x,
                    y: y
            )
        }) { _ in
            completion?()
        }
    }
}

extension CAShapeLayer {

    static func getRoundedRectPath(frame: CGRect, roundingCorners corners: UIRectCorner, withRadius radius: CGFloat) -> CGPath {
        UIBezierPath(roundedRect: frame,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)).cgPath
    }

    static func getRoundedRectShape(frame: CGRect, roundingCorners corners: UIRectCorner, withRadius radius: CGFloat) -> CAShapeLayer {

        let maskLayer = CAShapeLayer()

        maskLayer.path = getRoundedRectPath(
                frame: frame,
                roundingCorners: corners,
                withRadius: radius
        )

        return maskLayer
    }

    static func getRoundedRectPath(size: CGSize, lt: CGFloat, rt: CGFloat, lb: CGFloat, rb: CGFloat) -> CGPath {

        let path = UIBezierPath()
        path.move(to: CGPoint(x: lt, y: 0))
        path.addLine(to: CGPoint(x: size.width - rt, y: 0))
        path.addQuadCurve(to: CGPoint(x: size.width, y: rt), controlPoint: CGPoint(x: size.width, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height - rb))
        path.addQuadCurve(to: CGPoint(x: size.width - rb, y: size.height), controlPoint: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: lb, y: size.height))
        path.addQuadCurve(to: CGPoint(x: 0, y: size.height - lb), controlPoint: CGPoint(x: 0, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: lt))
        path.addQuadCurve(to: CGPoint(x: 0 + lt, y: 0), controlPoint: CGPoint(x: 0, y: 0))
        path.close()

        return path.cgPath
    }
}

extension UIAlertController {

    /// Creates a `UIAlertController` with a custom `UIView` instead the message text.
    /// - Note: In case anything goes wrong during replacing the message string with the custom view, a fallback message will
    /// be used as normal message string.
    ///
    /// - Parameters:
    ///   - title: The title text of the alert controller
    ///   - customView: A `UIView` which will be displayed in place of the message string.
    ///   - fallbackMessage: An optional fallback message string, which will be displayed in case something went wrong with inserting the custom view.
    ///   - preferredStyle: The preferred style of the `UIAlertController`.
    convenience init(title: String?, customView: UIView, fallbackMessage: String?, preferredStyle: UIAlertController.Style) {

        let marker = "__CUSTOM_CONTENT_MARKER__"
        self.init(title: title, message: marker, preferredStyle: preferredStyle)

        // Try to find the message label in the alert controller's view hierarchie
        if let customContentPlaceholder = view.findLabel(withText: marker),
           let customContainer = customContentPlaceholder.superview {

            // The message label was found. Add the custom view over it and fix the autolayout...
            customContainer.addSubview(customView)

            customView.translatesAutoresizingMaskIntoConstraints = false
            customContainer.heightAnchor.constraint(equalTo: customView.heightAnchor).isActive = true
            customContainer.topAnchor.constraint(equalTo: customView.topAnchor).isActive = true
            customContainer.leftAnchor.constraint(equalTo: customView.leftAnchor).isActive = true
            customContainer.rightAnchor.constraint(equalTo: customView.rightAnchor).isActive = true
            customContentPlaceholder.text = ""
        } else { // In case something fishy is going on, fall back to the standard behaviour and display a fallback message string
            message = fallbackMessage
        }
    }
}

private extension UIView {

    /// Searches a `UILabel` with the given text in the view's subviews hierarchy.
    ///
    /// - Parameter text: The label text to search
    /// - Returns: A `UILabel` in the view's subview hierarchy, containing the searched text or `nil` if no `UILabel` was found.
    func findLabel(withText text: String) -> UILabel? {
        if let label = self as? UILabel, label.text == text {
            return label
        }

        for subview in subviews {
            if let found = subview.findLabel(withText: text) {
                return found
            }
        }

        return nil
    }
}
