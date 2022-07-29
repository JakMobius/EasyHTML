//
//  GradientPicker.swift
//  Color Picker
//
//  Created by Артем on 14.11.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import Foundation
import UIKit

internal class TCGradient: NSObject, NSCoding, NSCopying {
    internal required init?(coder aDecoder: NSCoder) {
        colors = aDecoder.decodeObject(forKey: "1") as! [UIColor]
        location = aDecoder.decodeObject(forKey: "2") as! [NSNumber]
        startPoint = aDecoder.decodeCGPoint(forKey: "3")
        endPoint = aDecoder.decodeCGPoint(forKey: "4")
        isRadial = aDecoder.decodeBool(forKey: "5")
        angle = aDecoder.decodeFloat(forKey: "6")
    }

    internal func encode(with aCoder: NSCoder) {
        aCoder.encode(colors, forKey: "1")
        aCoder.encode(location, forKey: "2")
        aCoder.encode(startPoint, forKey: "3")
        aCoder.encode(endPoint, forKey: "4")
        aCoder.encode(isRadial, forKey: "5")
        aCoder.encode(angle, forKey: "6")
    }

    internal override func isEqual(_ object: Any?) -> Bool {
        if (object is TCGradient) {
            let gradient = object as! TCGradient

            if isRadial {
                return gradient.isRadial && gradient.colors == colors && gradient.location == location
            } else {
                return !gradient.isRadial && gradient.colors == colors && gradient.location == location && gradient.angle == angle
            }
        }
        return false
    }

    internal func copy(with zone: NSZone? = nil) -> Any {
        TCGradient(
                colors: colors,
                location: location,
                startPoint: startPoint,
                endPoint: endPoint,
                isRadial: isRadial,
                angle: angle
        )
    }

    internal var colors: [UIColor] = []
    internal var location: [NSNumber] = []
    internal var startPoint: CGPoint = CGPoint.zero
    internal var endPoint: CGPoint = CGPoint(x: 0, y: 1)
    internal var isRadial = false
    internal var angle: Float = 0.0

    internal init(colors: [UIColor], location: [NSNumber], startPoint: CGPoint, endPoint: CGPoint, isRadial: Bool, angle: Float) {
        self.colors = colors;
        self.location = location
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.isRadial = isRadial
        self.angle = angle
    }

    internal override init() {

    }
}

class GradientLayer: CALayer {

    private var _gradientOptions: CGGradientDrawingOptions = CGGradientDrawingOptions(rawValue: 0)
    private var _isRadial: Bool = false
    private var _startPoint: CGPoint = CGPoint.zero
    private var _endPoint: CGPoint = CGPoint(x: 0, y: 1)
    private var _locations: [CGFloat] = [0.0, 1.0]
    private var _colors = [UIColor.red.cgColor, UIColor.blue.cgColor]
    internal var pointsAreRelative = true

    internal var gradientOptions: CGGradientDrawingOptions {
        get {
            _gradientOptions
        }
        set {
            _gradientOptions = newValue; setNeedsDisplay()
        }
    }
    internal var isRadial: Bool {
        get {
            _isRadial
        }
        set {
            _isRadial = newValue; setNeedsDisplay()
        }
    }
    internal var startPoint: CGPoint {
        get {
            _startPoint
        }
        set {
            _startPoint = newValue; setNeedsDisplay()
        }
    }
    internal var endPoint: CGPoint {
        get {
            _endPoint
        }
        set {
            _endPoint = newValue; setNeedsDisplay()
        }
    }
    internal var locations: [CGFloat] {
        get {
            _locations
        }
        set {
            _locations = newValue; setNeedsDisplay()
        }
    }
    internal var colors: [CGColor] {
        get {
            _colors
        }
        set {
            _colors = newValue; setNeedsDisplay()
        }
    }

    required override init() {
        super.init()
        needsDisplayOnBoundsChange = true
        masksToBounds = true
        contentsScale = UIScreen.main.scale
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    required override init(layer: Any) {
        super.init(layer: layer)
    }


    override func draw(in ctx: CGContext) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let gradient = CGGradient(colorsSpace: colorSpace, colors: _colors as CFArray, locations: _locations)

        if (gradient == nil) {
            return;
        }

        ctx.saveGState()

        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        if (isRadial) {
            let radius = min(bounds.width * 0.707106, bounds.height * 0.707106)
            let center = CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0)
            ctx.drawRadialGradient(gradient!, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: radius, options: _gradientOptions)
        } else {
            if (pointsAreRelative) {
                let realStartPoint = CGPoint(x: startPoint.x * frame.width, y: startPoint.y * frame.height)
                let realEndPoint = CGPoint(x: endPoint.x * frame.width, y: endPoint.y * frame.height)
                ctx.drawLinearGradient(gradient!, start: realStartPoint, end: realEndPoint, options: _gradientOptions)
            } else {
                ctx.drawLinearGradient(gradient!, start: startPoint, end: endPoint, options: _gradientOptions)
            }
        }
    }
}

@objc internal protocol GradientPickerDelegate {
    @objc optional func gradientPicker(didChange sender: GradientPicker)
    @objc optional func gradientPicker(willDisappear sender: GradientPicker)
    @objc optional func gradientPicker(didConfirm sender: GradientPicker)
}

internal class GradientPicker: UIViewController, UITableViewDataSource, UITabBarDelegate, UITextFieldDelegate, UITableViewDelegate, ColorPickerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UIGestureRecognizerDelegate, NotificationHandler {

    @IBOutlet var container: UIView!
    @IBOutlet var recentCollection: UICollectionView!
    @IBOutlet var recentContainer: UIView!
    @IBOutlet var gradientPreview: GradientView!
    @IBOutlet var rotationTextField: PaddedTextField!
    @IBOutlet var sliderContainer: UIView!
    @IBOutlet var containerLargeHeightConstraint: NSLayoutConstraint!
    @IBOutlet var containerSmallHeightConstraint: NSLayoutConstraint!
    @IBOutlet var slider: UISlider!
    @IBOutlet var colorTableView: UITableView!
    @IBOutlet var radialGradientPreview: GradientView!
    @IBOutlet var segmentedControl: UISegmentedControl!
    @IBOutlet var leadingContainerConstraint: NSLayoutConstraint!
    @IBOutlet var trailingContainerConstraint: NSLayoutConstraint!

    @IBOutlet var rotationAngleLabel: UILabel!
    @IBOutlet var recentLabel: UILabel!

    private var accessoryView = UIToolbar()
    private var isRadial = false
    private var cells = [GradientPickerTableComponentCell]()
    internal static var recentGradientsList = [TCGradient]()
    private static var didLastGradientsLoaded = false
    private var prefix = ""
    private var unsupportedRadialGradientOptions = ""

    private var currentlyEditingCellNumber = 0
    private var cellInitialColor: UIColor?
    private var swipeGesture: UIGestureRecognizer!

    private var currentEditingTextField: UITextField?

    internal var currentGradient = TCGradient()
    private weak var delegate: GradientPickerDelegate?
    private var gradientPickerDidConfirm = false
    private var gestureRotationOrigin: CGFloat = 0.0

    internal override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGradient()
        containerLargeHeightConstraint.isActive = !isRadial
        containerSmallHeightConstraint.isActive = isRadial
    }

    func deviceRotated() {
        if UIDevice.current.hasAnEyebrow {
            transitionManager()
        }
    }

    static func present(from: UIViewController, origin: UIView?, completion: (() -> Swift.Void)? = nil) -> GradientPickerNavigationController {
        let screenSize = UIScreen.main.bounds

        let storyboard: UIStoryboard = UIStoryboard(name: "Misc", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "GradientPicker") as! GradientPickerNavigationController
        let minsize = min(screenSize.width, screenSize.height)

        if (minsize < 380) {
            vc.presentedModally = false
        }
        if (origin != nil && minsize > 414) {
            vc.modalPresentationStyle = .popover
            let popover = vc.popoverPresentationController
            popover?.sourceView = from.view
            popover?.sourceRect = origin!.frame
            vc.presentedAsPopover = true
        } else {
            vc.modalPresentationStyle = .pageSheet
        }

        from.present(vc, animated: true, completion: completion)

        return vc
    }

    internal func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
        0
    }

    internal func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 10 : 0
    }

    @objc func segmentedControlValueDidChange(_ sender: UISegmentedControl) {
        let isZero = sender.selectedSegmentIndex == 0
        isRadial = !isZero
        currentGradient.isRadial = isRadial

        view.setNeedsUpdateConstraints()

        UIView.animate(withDuration: 0.3, animations: {

            if (isZero) {
                self.sliderContainer.isHidden = false
                self.gradientPreview.superview!.isHidden = false
            } else {
                self.radialGradientPreview.superview!.isHidden = false
            }

            self.containerLargeHeightConstraint.isActive = isZero
            self.containerSmallHeightConstraint.isActive = self.isRadial

            self.view.layoutIfNeeded()
            self.sliderContainer.alpha = isZero ? 1.0 : 0.0
            self.radialGradientPreview.superview!.alpha = self.isRadial ? 1.0 : 0.0
            self.gradientPreview.superview!.alpha = isZero ? 1.0 : 0.0

            self.updateGradientColors()
            self.updateGradient()

        }) {
            _ in
            if (self.isRadial) {
                self.gradientPreview.superview!.isHidden = true
                self.sliderContainer.isHidden = true
            } else {
                self.radialGradientPreview.superview!.isHidden = true
            }
        }
        delegate?.gradientPicker?(didChange: self)
    }

    // TODO: improve reading mechanism

    internal static func loadLastColors() {

        GradientPicker.recentGradientsList = []

        var i = 0;

        while (true) {
            let key = "gradient\(i)"

            let gradient = Defaults.tcgradient(forKey: key)

            if (gradient == nil) {
                break
            }

            GradientPicker.recentGradientsList.append(gradient!)

            i += 1
        }

        if (i == 0) {
            GradientPicker.recentGradientsList = [
                TCGradient(colors: [UIColor.green, UIColor.yellow], location: [0.0, 1.0], startPoint: CGPoint(x: 0, y: 1), endPoint: CGPoint.zero, isRadial: false, angle: 0.0),
                TCGradient(colors: [UIColor.clear, UIColor.red], location: [0.0, 1.0], startPoint: CGPoint.zero, endPoint: CGPoint.zero, isRadial: true, angle: 0.0),
                TCGradient(colors: [UIColor.orange, UIColor.yellow], location: [0.0, 1.0], startPoint: CGPoint.zero, endPoint: CGPoint(x: 1, y: 0), isRadial: true, angle: 0.0),
                TCGradient(colors: [UIColor.orange, UIColor.yellow], location: [0.0, 1.0], startPoint: CGPoint(x: 1, y: 0), endPoint: CGPoint(x: 0, y: 1), isRadial: false, angle: 225.0),
                TCGradient(colors: [UIColor.blue, UIColor.magenta], location: [0.0, 1.0], startPoint: CGPoint(x: 0, y: 1), endPoint: CGPoint(x: 1, y: 0), isRadial: false, angle: 45.0),
            ]
        }
    }

    override internal func viewDidLoad() {

        title = localize("gradientpick")

        segmentedControl.setTitle(localize("linear"), forSegmentAt: 0)
        segmentedControl.setTitle(localize("radial"), forSegmentAt: 1)

        rotationAngleLabel.text = localize("rotationangle")

        recentLabel.text = localize("recent")

        if (!GradientPicker.didLastGradientsLoaded) {
            GradientPicker.loadLastColors()
        }

        if #available(iOS 11.0, *) {
            colorTableView.insetsContentViewsToSafeArea = false
        }

        let nc = navigationController as! GradientPickerNavigationController
        prefix = nc.gradientPrefix
        unsupportedRadialGradientOptions = nc.radialGradientUnsupportedOptions
        delegate = nc.gradientDelegate

        recentCollection.delegate = self
        recentCollection.dataSource = self

        swipeGesture = UIPanGestureRecognizer(target: self, action: #selector(slideToRecentGestureRecogniser))
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapAction))

        swipeGesture.delegate = self

        view.addGestureRecognizer(swipeGesture)
        container.addGestureRecognizer(tapGesture)

        colorTableView.dataSource = self
        colorTableView.delegate = self

        colorTableView.sectionFooterHeight = 0
        colorTableView.sectionHeaderHeight = 0

        rotationTextField.delegate = self
        let options: CGGradientDrawingOptions = [.drawsAfterEndLocation, .drawsBeforeStartLocation]
        radialGradientPreview.gradientLayer.gradientOptions = options
        gradientPreview.gradientLayer.gradientOptions = options
        gradientPreview.gradientLayer.pointsAreRelative = false

        radialGradientPreview.superview!.alpha = 0.0
        radialGradientPreview.superview!.isHidden = true
        radialGradientPreview.gradientLayer.isRadial = true
        radialGradientPreview.layer.shadowColor = UIColor(white: 0.0, alpha: 0.7).cgColor
        radialGradientPreview.layer.shadowOffset = CGSize(width: 0, height: 2)
        radialGradientPreview.layer.shadowOpacity = 1.0
        gradientPreview.layer.shadowColor = UIColor(white: 0.0, alpha: 0.7).cgColor
        gradientPreview.layer.shadowOffset = CGSize(width: 0, height: 2)
        gradientPreview.layer.shadowOpacity = 1.0

        radialGradientPreview.gradientLayer.cornerRadius = 6.0
        gradientPreview.gradientLayer.cornerRadius = 6.0

        accessoryView.items = [
            UIBarButtonItem(title: localize("ready"), style: UIBarButtonItem.Style.done, target: self, action: #selector(resignFirstResponders)),
            UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        ]

        accessoryView.sizeToFit()

        rotationTextField.addTarget(self, action: #selector(textFieldValueDidChange(_:)), for: .editingChanged)
        rotationTextField.inputAccessoryView = accessoryView
        rotationTextField.tag = 1

        slider.addTarget(self, action: #selector(sliderValueDidChange), for: .valueChanged)

        NotificationCenter.default.addObserver(self, selector: #selector(ColorPicker.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ColorPicker.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ColorPicker.keyboardWillShow), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        segmentedControl.addTarget(self, action: #selector(segmentedControlValueDidChange), for: .valueChanged)

        let backButton = UIBarButtonItem(title: localize("ready"), style: .done, target: self, action: #selector(doneButtonAction))

        if ((navigationController as! GradientPickerNavigationController).presentedAsPopover) {
            navigationItem.rightBarButtonItem = backButton

        } else {
            let cancelButton = UIBarButtonItem(title: localize("cancel"), style: .plain, target: self, action: #selector(cancelButtonAction))

            navigationItem.rightBarButtonItem = cancelButton
            navigationItem.leftBarButtonItem = backButton
        }

        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotateGradientByGesture))

        rotationGestureRecognizer.delegate = self

        gradientPreview.addGestureRecognizer(rotationGestureRecognizer)

        setGradient(newGradient: nc.initialGradient ?? GradientPicker.recentGradientsList.first!)

        transitionManager(animation: false)

        setupRotationNotificationHandling()
    }

    internal func getCode() -> String {

        var result = ""

        if (currentGradient.isRadial) {
            result = "\(prefix)radial-gradient("
            if (unsupportedRadialGradientOptions != "") {
                result += "\(unsupportedRadialGradientOptions), "
            }
        } else {

            switch (slider.value) {
            case 0, 360: result = "to top, "; break;
            case 45: result = "to top right, "; break;
            case 90: result = "to right, "; break;
            case 135: result = "to bottom right, "; break;
            case 225: result = "to bottom left, "; break;
            case 270: result = "to left, "; break;
            case 315: result = "to top left, "; break;
            default: result = "\(Int(slider.value))deg, "
            }
            result = "\(prefix)linear-gradient(\(result)"


        }

        for i in 0..<currentGradient.colors.count {
            if (i != 0) {
                result += ", "
            }
            result += "\(ColorPicker.getColorNameBy(color: currentGradient.colors[i])) \(round(currentGradient.location[i].floatValue * 100))%"
        }

        return "\(result))"
    }

    internal static func positionsFromAngle(degree: CGFloat, mult: CGFloat = 1.0) -> [CGPoint] {
        let degree = (9.42478 - degree).truncatingRemainder(dividingBy: 2 * .pi)
        var mult = mult
        mult /= 2;
        let sine = sin(degree)
        let cosine = cos(degree)
        let length = CGFloat(abs(sin(degree * .pi / 90)))
        let amplifier: CGFloat = sqrt(length + 1) * mult

        let startPoint = CGPoint(x: mult - sine * amplifier, y: mult - cosine * amplifier)
        let endPoint = CGPoint(x: mult + sine * amplifier, y: mult + cosine * amplifier)

        return [startPoint, endPoint]
    }

    private func updateGradient() {

        if (!isRadial) {
            let degree: CGFloat = CGFloat(slider.value * .pi / 180)
            let width = gradientPreview.frame.width
            let height = gradientPreview.frame.height

            if (width == 0 || height == 0) {
                return
            }

            let center = CGPoint(x: width / 2, y: height / 2)

            let pos = GradientPicker.positionsFromAngle(degree: degree, mult: min(width, height))

            currentGradient.startPoint = pos[0]
            currentGradient.endPoint = pos[1]

            CATransaction.begin()
            CATransaction.setValue(true, forKey: kCATransactionDisableActions)

            gradientPreview.gradientLayer.startPoint = currentGradient.startPoint
            gradientPreview.gradientLayer.endPoint = currentGradient.endPoint

            if (center.x > center.y) {
                gradientPreview.gradientLayer.transform = CATransform3DMakeScale(center.x / center.y, 1, 1)
            } else if (center.x < center.y) {
                gradientPreview.gradientLayer.transform = CATransform3DMakeScale(1, center.y / center.x, 1)
            } else {
                gradientPreview.gradientLayer.transform = CATransform3DMakeScale(1, 1, 1)
            }

            CATransaction.commit()
        }
    }

    private func updateGradientColors(updateColors: Bool = true, updateLocations: Bool = true) {
        let gradient = isRadial ? radialGradientPreview.gradientLayer : gradientPreview.gradientLayer

        if (updateLocations) {
            gradient.locations = []
            currentGradient.location.forEach {
                location in

                gradient.locations.append(CGFloat(truncating: location))
            }
        }

        if (updateColors) {
            gradient.colors = []

            currentGradient.colors.forEach {
                color in
                gradient.colors.append(color.cgColor)
            }
        }
    }

    internal func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? currentGradient.colors.count : 1
    }

    internal func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == 0 ? 0.1 : 20
    }

    internal func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 20 : 10
    }

    @objc func resignFirstResponders() {
        view.endEditing(true)
    }

    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath.section == 0) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "component") as! GradientPickerTableComponentCell

            cell.inputField.inputAccessoryView = accessoryView

            let color = currentGradient.colors[indexPath.row]

            cell.colorPreview.backgroundColor = color
            cell.inputField.text = "\(round(Double(truncating: currentGradient.location[indexPath.row]) * 1000) / 10.0)"
            cell.colorPreview.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3).cgColor
            cell.colorPreview.layer.shadowRadius = 3.0
            cell.colorPreview.layer.shadowOpacity = 1.0
            cell.colorPreview.layer.shadowOffset = CGSize(width: 0, height: 1)
            cell.selectionStyle = .none
            cell.inputField.delegate = self
            cell.inputField.addTarget(self, action: #selector(textFieldValueDidChange(_:)), for: .editingChanged)
            cell.gestureView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(colorChangeAction(_:))))
            cell.colorName.text = ColorPicker.getColorNameBy(color: color)

            if (cells.count <= indexPath.row) {
                cells.append(cell)
            } else {
                cells[indexPath.row] = cell
            }

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "add") as! GradientPickerTableAddCell

            cell.button.addTarget(self, action: #selector(addNewColor), for: .touchUpInside)

            return cell
        }
    }

    @objc internal func addNewColor(_ sender: UIButton) {
        currentlyEditingCellNumber = cells.count
        currentGradient.location.append(1.0)
        currentGradient.colors.append(UIColor.white)
        colorTableView.insertRows(at: [IndexPath(row: currentlyEditingCellNumber, section: 0)], with: .left)

        editColor(for: cells[currentlyEditingCellNumber].contentView)

        updateGradientColors()
    }

    @objc internal func sliderValueDidChange() {

        rotationTextField.text = String(round(slider.value * 10) / 10.0)
        updateGradient()
        delegate?.gradientPicker?(didChange: self)
    }

    @objc internal func rotateGradientByGesture(_ sender: UIRotationGestureRecognizer) {
        if (sender.state.rawValue == 3) {
            gestureRotationOrigin = 0
            swipeGesture.isEnabled = true
            return
        }

        swipeGesture.isEnabled = false

        let rotation = sender.rotation / .pi * 180.0 - gestureRotationOrigin

        gestureRotationOrigin += rotation

        let newValue = (slider.value + Float(rotation)).truncatingRemainder(dividingBy: 360)

        slider.value = newValue < 0 ? 360 - newValue : newValue
        sliderValueDidChange()

        updateGradient()
    }

    internal func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

        let str = (textField.text! + string)
        let maxLength = str.contains(",") ? 5 : 3

        if str.count > maxLength {
            textField.text = String(str.prefix(maxLength))

            return false
        }

        return true
    }

    internal func textFieldDidBeginEditing(_ textField: UITextField) {
        currentEditingTextField = textField

        if (textField.tag != 1) {
            let view = textField.superview

            var i = 0

            for cell in cells {
                if (cell.contentView == view) {
                    currentlyEditingCellNumber = i
                    break;
                }
                i += 1
            }
        }
    }

    @objc internal func textFieldValueDidChange(_ textField: UITextField) {
        let value = max(min(Double(textField.text!) ?? 0.0, textField.tag == 1 ? 360.0 : 100.0), 0)

        if (textField.tag == 0) {
            let index = findIndexOfTextField(textField)
            if (index < cells.count) {
                currentGradient.location[index] = NSNumber(value: value / 100)
            }
            updateGradientColors(updateColors: false)
        } else {
            updateGradient()
            slider.value = Float(value)
        }
        delegate?.gradientPicker?(didChange: self)
    }

    internal func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        localize("remove")
    }

    internal func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 0
    }


    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCell.EditingStyle.delete) {
            let row = indexPath.row
            currentGradient.colors.remove(at: row)
            currentGradient.location.remove(at: row)
            cells.remove(at: row)

            updateGradientColors()

            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    private func findIndexOfTextField(_ textField: UITextField) -> Int {
        var index = 0;
        for cell in cells {
            if (cell.inputField == textField) {
                break
            }

            index += 1
        }

        return index
    }

    internal func textFieldDidEndEditing(_ textField: UITextField) {
        var flag = textField.tag == 1
        var value = max(min(Double(textField.text!) ?? 0.0, flag ? 360.0 : 100.0), 0)
        textField.text = String(value)

        if (flag) {
            return
        }

        value /= 100

        let index = findIndexOfTextField(textField)

        if (index >= cells.count) {
            updateGradientColors(updateColors: false)
            return;
        }

        var i = 0
        flag = true
        for location in currentGradient.location {
            if (flag && i == index) {
                flag = false
                continue
            }
            if (location.doubleValue > value) {
                break
            }

            i += 1
        }

        if (index >= cells.count) {
            return
        }

        if (index == i) {
            currentGradient.location[index] = NSNumber(value: value)
            updateGradientColors(updateColors: false)
            return;
        }

        let cell = cells.remove(at: index)
        cells.insert(cell, at: i)
        let color = currentGradient.colors.remove(at: index)
        currentGradient.colors.insert(color, at: i)
        currentGradient.location.remove(at: index)
        currentGradient.location.insert(NSNumber(value: value), at: i)

        colorTableView.moveRow(at: IndexPath(row: index, section: 0), to: IndexPath(row: i, section: 0))

        updateGradientColors()
    }

    private var translate: CGFloat = 0 {
        didSet {
            view.transform.ty = -translate
        }
    }

    func keyboardWillHide(sender: NSNotification) {
        translate = 0
    }

    func keyboardWillShow(sender: NSNotification) {
        if (currentEditingTextField == nil) {
            return
        }
        let userInfo = sender.userInfo!
        var offset: CGSize = (userInfo[UIResponder.keyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue.size
        if offset.width < UIScreen.main.bounds.width {
            offset.height = 0
        }
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber

        let slidersContainerBounds = colorTableView!.globalFrame!

        var y = UIScreen.main.bounds.height - slidersContainerBounds.maxY - translate
        y -= offset.height
        y = min(0, y)

        UIView.animate(withDuration: animationDuration?.doubleValue ?? 0.1, animations: { () -> Void in
            self.translate = -y
        })
    }

    internal override func viewWillDisappear(_ animated: Bool) {
        if (gradientPickerDidConfirm) {
            return
        }
        delegate?.gradientPicker?(willDisappear: self)
    }

    @objc func doneButtonAction(_ sender: UIBarButtonItem) {
        currentGradient.angle = round(slider.value * 10) / 10.0

        if let index = GradientPicker.recentGradientsList.firstIndex(of: currentGradient) {
            GradientPicker.recentGradientsList.remove(at: index)
        }

        let gradient = currentGradient.copy() as! TCGradient

        gradient.startPoint = CGPoint(
                x: gradient.startPoint.x / gradientPreview.frame.width,
                y: gradient.startPoint.y / gradientPreview.frame.height
        )

        gradient.endPoint = CGPoint(
                x: gradient.endPoint.x / gradientPreview.frame.width,
                y: gradient.endPoint.y / gradientPreview.frame.height
        )

        GradientPicker.recentGradientsList.insert(gradient, at: 0)
        writeLastGradients()
        delegate?.gradientPicker?(didConfirm: self)
        gradientPickerDidConfirm = true
        dismiss(animated: true, completion: nil)
    }

    private func writeLastGradients() {
        let defaults = UserDefaults.standard
        var i = 0

        for gradient in GradientPicker.recentGradientsList {

            Defaults.set(gradientHolder: gradient, forKey: "gradient\(i)")
            i += 1
            if (i >= 30) {
                break;
            }
        }

        var key = ""
        while (true) {
            key = "gradient\(i)"
            if (defaults.object(forKey: key) == nil) {
                break;
            }
            defaults.removeObject(forKey: key)
        }
    }

    @objc func cancelButtonAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    func editColor(for view: UIView, initialColor: UIColor? = nil) {
        cellInitialColor = initialColor
        ColorPicker.present(inNavigationViewController: navigationController!)
                .setInitialColor(initialColor ?? ColorPicker.getLastColors().first ?? UIColor.green)
                .setColorPickerDelegate(self)

        var i = 0
        for cell in cells {
            if (cell.contentView == view.superview!) {
                currentlyEditingCellNumber = i
                break
            }
            i += 1
        }
    }

    @objc func colorChangeAction(_ sender: UITapGestureRecognizer) {

        editColor(for: sender.view!, initialColor: (sender.view?.superview?.viewWithTag(553)?.backgroundColor)!)
    }

    private func dynamicColorChange(color: UIColor?, shouldDelete: Bool = true) {
        if (color == nil) {
            if (shouldDelete) {
                currentGradient.colors.remove(at: currentlyEditingCellNumber)
                currentGradient.location.remove(at: currentlyEditingCellNumber)
                cells.remove(at: currentlyEditingCellNumber)

                updateGradientColors()

                colorTableView.deleteRows(at: [IndexPath(row: currentlyEditingCellNumber, section: 0)], with: .none)
            }
        } else {
            currentGradient.colors[currentlyEditingCellNumber] = color!
            let cell = cells[currentlyEditingCellNumber]
            cell.colorPreview.backgroundColor = color
            cell.colorName.text = ColorPicker.getColorNameBy(color: color!)
        }

        updateGradientColors(updateColors: true, updateLocations: false)
    }

    internal func colorPicker(colorPickerWillDisappear sender: ColorPicker) {
        dynamicColorChange(color: sender.currentColor)
        delegate?.gradientPicker?(didChange: self)
    }

    internal func colorPicker(colorPickerDidCancel sender: ColorPicker) {
        dynamicColorChange(color: cellInitialColor, shouldDelete: true)
    }

    var slideStartPosition = CGPoint()
    var slideConfirmed = false
    var slided = false

    @objc func slideToRecentGestureRecogniser(_ sender: UIPanGestureRecognizer) {
        let location = sender.location(in: sender.view)
        var deltaX = location.x - slideStartPosition.x

        if sender.state == .began {
            slideStartPosition = sender.location(in: sender.view)
        } else if sender.state == .ended || sender.state == .failed || sender.state == .cancelled {

            slideConfirmed = false

            if (abs(deltaX) > recentContainer.frame.width / 3 && (deltaX < 0) == slided) {
                slided = !slided
            }

            UIView.animate(withDuration: 0.3, animations: {
                self.recentContainer.transform = CGAffineTransform(translationX: self.slided ? self.recentContainer.frame.width : 0, y: 0)
            }, completion: {
                success in
                if (success) {
                    self.recentContainer.isHidden = !self.slided
                }
            })
        } else {


            if !slideConfirmed {
                if (slided) {
                    deltaX = -deltaX
                }

                let deltaY = abs(location.y - slideStartPosition.y)
                if deltaX > 10 && (deltaY == 0 || deltaX / deltaY > 3.0) {
                    slideConfirmed = true
                }
            } else {
                recentContainer.isHidden = false
                recentContainer.transform = CGAffineTransform(translationX: max(min(slided ? recentContainer.frame.width + deltaX : deltaX, recentContainer.frame.width), 0), y: 0)
            }
        }
    }

    @objc func tapAction(_ sender: UITapGestureRecognizer) {
        if (slided) {
            slided = false
            UIView.animate(withDuration: 0.3) {
                self.recentContainer.transform = CGAffineTransform.identity
            }
        }
    }

    internal func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        GradientPicker.recentGradientsList.count
    }

    internal func setGradient(newGradient: TCGradient) {
        cells = []
        let needsChangeRadialState = currentGradient.isRadial != newGradient.isRadial
        currentGradient = (newGradient.copy() as? TCGradient)!

        if (!newGradient.isRadial) {
            slider.setValue(currentGradient.angle, animated: true)
            rotationTextField.text = "\(currentGradient.angle)"
        }

        updateGradientColors()
        colorTableView.reloadData()

        if (needsChangeRadialState) {
            segmentedControl.selectedSegmentIndex = newGradient.isRadial ? 1 : 0
            segmentedControlValueDidChange(segmentedControl)
        }
    }

    internal func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let newGradient = GradientPicker.recentGradientsList[indexPath.row]
        setGradient(newGradient: newGradient)

        delegate?.gradientPicker?(didChange: self)

        slided = false
        UIView.animate(withDuration: 0.3) {
            self.recentContainer.transform = CGAffineTransform.identity
        }
    }

    internal func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gradient", for: indexPath) as! RecentGradientsCollectionViewCell

        let gradient = GradientPicker.recentGradientsList[indexPath.row]

        var realColorsList = [CGColor]()

        gradient.colors.forEach {
            gradientColor in
            realColorsList.append(gradientColor.cgColor)
        }

        var realLocations = [CGFloat]()

        gradient.location.forEach {
            gradientLocation in
            realLocations.append(CGFloat(truncating: gradientLocation))
        }

        cell.gradientView.layer.frame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 40.0)
        cell.gradientView.gradientLayer.colors = realColorsList
        cell.gradientView.gradientLayer.locations = realLocations
        cell.gradientView.gradientLayer.startPoint = gradient.startPoint
        cell.gradientView.gradientLayer.endPoint = gradient.endPoint
        cell.gradientView.gradientLayer.isRadial = gradient.isRadial
        cell.gradientView.gradientLayer.cornerRadius = 3.0
        cell.gradientView.gradientLayer.gradientOptions = [.drawsAfterEndLocation, .drawsBeforeStartLocation]

        cell.layer.cornerRadius = 3.0
        cell.layer.shadowColor = UIColor(white: 0.0, alpha: 0.3).cgColor
        cell.layer.shadowOpacity = 1.0
        cell.layer.shadowRadius = 3.0
        cell.layer.shadowOffset = CGSize(width: 0, height: 2)
        cell.layer.masksToBounds = false;
        cell.layer.shadowPath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: cell.contentView.layer.cornerRadius).cgPath

        return cell
    }

    func transitionManager(animation: Bool = true) {
        if #available(iOS 11.0, *), UIDevice.current.hasAnEyebrow {
            let orientation = UIApplication.shared.statusBarOrientation
            if orientation == .landscapeRight {
                leadingContainerConstraint?.constant = 33
                trailingContainerConstraint?.constant = 4
            } else if orientation == .landscapeLeft {
                leadingContainerConstraint?.constant = 0
                trailingContainerConstraint?.constant = 34
            } else {
                leadingContainerConstraint?.constant = 0
                trailingContainerConstraint?.constant = 4
            }
        } else {
            leadingContainerConstraint?.constant = 0
            trailingContainerConstraint?.constant = 4
        }

        colorTableView.setNeedsLayout()

        if animation {
            UIView.animate(withDuration: 0.3, animations: view.layoutIfNeeded)
        } else {
            updateViewConstraints()
        }
    }

    internal func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        if gestureRecognizer == swipeGesture {
            return !slided
        }

        return true
    }

    deinit {
        clearNotificationHandling()
    }
}

internal class GradientPickerTableComponentCell: UITableViewCell {
    @IBOutlet internal var gestureView: UIView!
    @IBOutlet internal var colorPreview: UIView!
    @IBOutlet internal var inputField: PaddedTextField!
    @IBOutlet internal var colorName: UILabel!
}

internal class GradientPickerTableAddCell: UITableViewCell {

    @IBOutlet internal var button: UIButton!
}

internal class GradientPickerNavigationController: ThemeColoredNavigationController {
    internal var presentedAsPopover = false
    internal var presentedModally = true
    internal weak var gradientDelegate: GradientPickerDelegate?
    internal var initialGradient: TCGradient?
    internal var gradientPrefix = ""
    internal var radialGradientUnsupportedOptions = ""

    @discardableResult internal func setGradientPickerDelegate(_ gradientDelegate: GradientPickerDelegate) -> GradientPickerNavigationController {
        self.gradientDelegate = gradientDelegate
        return self
    }

    @discardableResult internal func setGradient(_ gradient: TCGradient) -> GradientPickerNavigationController {
        initialGradient = gradient
        return self
    }

    @discardableResult internal func setPrefix(_ prefix: String) -> GradientPickerNavigationController {
        gradientPrefix = prefix
        return self
    }

    @discardableResult internal func setGradientUnsupportedOptions(_ options: String) -> GradientPickerNavigationController {
        radialGradientUnsupportedOptions = options
        return self
    }
}

internal class RecentGradientsCollectionViewCell: UICollectionViewCell {
    @IBOutlet internal var gradientView: GradientView!

}
