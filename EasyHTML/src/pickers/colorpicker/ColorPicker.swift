//
//  ViewController.swift
//  Color Picker
//
//  Created by Артем on 05.11.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

extension UIView {
    @IBInspectable var cornerRadius: CGFloat {
        get {return self.layer.cornerRadius}
        set {self.layer.cornerRadius = newValue}
    }
}

extension Defaults {
    
    static func tcgradient(forKey key: String) -> TCGradient? {
        var gradient: TCGradient?
        if let gradientData = data(forKey: key) {
            gradient = NSKeyedUnarchiver.unarchiveObject(with: gradientData) as? TCGradient
        }
        
        return gradient
    }
    
    static func set(gradientHolder: TCGradient?, forKey key: String) {
        var gradientData: NSData?
        if let gradient = gradientHolder {
            gradientData = NSKeyedArchiver.archivedData(withRootObject: gradient) as NSData
        }
        set(gradientData, forKey: key)
    }
    
    static func color(forKey: String) -> UIColor? {
        var color: UIColor?
        if let colorData = data(forKey: forKey) {
            color = NSKeyedUnarchiver.unarchiveObject(with: colorData) as? UIColor
        }
        return color
    }
    
    static func set(color: UIColor?, forKey key: String) {
        var colorData: NSData?
        if let color = color {
            colorData = NSKeyedArchiver.archivedData(withRootObject: color) as NSData
        }
        set(colorData, forKey: key)
    }
    
}

@IBDesignable internal class StackedImageView: UIImageView {
    
    @IBInspectable var stackedImage: UIImage? = nil;
    @IBInspectable var contentScale: CGFloat = 1.0
    
    override internal func awakeFromNib() {
        super.awakeFromNib()
        image = stackedImage?.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
        self.contentScaleFactor = contentScale
    }
}

@IBDesignable internal class GradientView: UIView {
    
    @IBInspectable internal var firstColor: UIColor = UIColor.clear
    @IBInspectable internal var secondColor: UIColor = UIColor.clear
    
    @IBInspectable internal var startPoint: CGPoint = CGPoint.zero
    @IBInspectable internal var endPoint: CGPoint = CGPoint(x:0, y:1)
    
    let gradientLayer = GradientLayer()
    
    override internal func awakeFromNib() {
        self.backgroundColor = UIColor.clear
        gradientLayer.frame.size = self.bounds.size
        gradientLayer.frame.origin = CGPoint.zero
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.colors = [firstColor.cgColor, secondColor.cgColor]
        self.layer.addSublayer(gradientLayer)
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame.size = self.bounds.size
        gradientLayer.frame.origin = CGPoint.zero
    }
}

@IBDesignable internal class GradientSlider: UIView {
    let gradientLayer = GradientLayer()
    let thumb = UIView()
    
    private var _value: Float = 0.5;
    private var _maxValue: Float = 1.0;
    private var _minValue: Float = 0.0;
    
    @IBInspectable internal var gestureHeight: CGFloat = 30.0
    
    private var targets: [Any?] = []
    private var selectors: [Selector?] = []
    
    var maxValue: Float {
        get { return _maxValue }
        set {
            _maxValue = newValue;
            if(_maxValue < _minValue) { _minValue = _maxValue }
            if(_maxValue > _value) { _value = _maxValue }
            
            redrawThumb()
        }
    }
    var value: Float {
        get { return _value }
        set {
            _value = max(_minValue, min(_maxValue, newValue))
            redrawThumb()
        }
    }
    var minValue: Float {
        get { return _minValue }
        set {
            _minValue = newValue
            if(_maxValue < _minValue) { _maxValue = _minValue }
            if(_minValue > _value) { _value = _minValue }
            
            redrawThumb()
        }
    }
    
    private func redrawThumb(){
        thumb.frame.origin.x = CGFloat((_value - _minValue) / (_maxValue - _minValue)) * (self.frame.width - 30)
    }
    
    private var _firstColor: UIColor = UIColor.red
    private var _secondColor: UIColor = UIColor.green
    
    var firstColor: UIColor {
        get { return _firstColor }
        set { _firstColor = newValue }
    }
    var secondColor: UIColor {
        get { return _secondColor }
        set { _secondColor = newValue }
    }
    
    func setColors(first: UIColor, second: UIColor, animated: Bool = false)
    {
        _firstColor = first
        _secondColor = second
        
        redrawGradient(animated: animated)
    }
    
    private func redrawGradient(animated: Bool = false){
        
        CATransaction.begin()
        if(animated)
        {
            CATransaction.setValue(0.3, forKey: kCATransactionAnimationDuration)
        } else {
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        }
        gradientLayer.colors = [firstColor.cgColor, secondColor.cgColor]
        CATransaction.commit()
    }
    
    func addTarget(_ target: Any?, action: Selector?){
        targets.append(target)
        selectors.append(action)
    }
    
    override internal func awakeFromNib() {
        super.awakeFromNib()
        
        let topPosition = (gestureHeight - 30) / 2
        
        self.layer.addSublayer(gradientLayer)
        self.addSubview(thumb)
        
        self.backgroundColor = UIColor.clear
        
        gradientLayer.frame.origin = CGPoint(x:0, y:12.5 + topPosition)
        gradientLayer.frame.size.height = 5
        gradientLayer.locations = [0.0,1.0]
        gradientLayer.startPoint = CGPoint.zero
        gradientLayer.endPoint = CGPoint(x:1, y:0)
        gradientLayer.cornerRadius = 3.0
        
        self.frame.size.height = gestureHeight;
        
        thumb.frame.size = CGSize(width: 30, height: 30)
        thumb.frame.origin.y = topPosition
        thumb.backgroundColor = UIColor.white
        thumb.layer.cornerRadius = 15;
        thumb.layer.shadowColor = UIColor.init(white: 0, alpha: 0.4).cgColor
        thumb.layer.shadowOffset = CGSize(width:0, height:3)
        thumb.layer.shadowOpacity = 1
        thumb.layer.shadowRadius = 4
        thumb.layer.shadowPath = UIBezierPath(ovalIn: thumb.bounds).cgPath
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(GradientSlider.panAction(_ : )))
        
        self.addGestureRecognizer(panGesture)
    }
    
    @objc func panAction(_ sender: UIPanGestureRecognizer){
        var newValue = (Float((sender.location(in: self).x - 15) / self.frame.width) * (_maxValue - _minValue) + _minValue)
        newValue = (newValue / Float(self.frame.width / (self.frame.width + 30)))
        
        self.value = newValue
        
        var i = 0;
        for selector in selectors {
            let target = targets[i]
            if(selector != nil && target != nil)
            {
                _ = (target as AnyObject).perform(selector, with: self)
            }
            
            i+=1
        }
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame.size.width = self.bounds.width
        
        redrawThumb()
        redrawGradient()
    }
}

@IBDesignable internal class PaddedTextField: UITextField {
    
    @IBInspectable var paddingTop: CGFloat = 7
    @IBInspectable var paddingLeft: CGFloat = 0
    @IBInspectable var paddingBottom: CGFloat = 0
    @IBInspectable var paddingRight: CGFloat = 3
    
    var padding: UIEdgeInsets! = nil;
    
    private func checkPadding() {
        if(padding == nil) {
            padding = UIEdgeInsets(top: paddingTop, left: paddingLeft, bottom: paddingBottom, right: paddingRight)
        }
    }
    
    override internal func textRect(forBounds bounds: CGRect) -> CGRect {
        checkPadding()
        
        return bounds.inset(by: padding)
    }
    
    override internal func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        checkPadding()
        return bounds.inset(by: padding)
    }
    
    override internal func editingRect(forBounds bounds: CGRect) -> CGRect {
        checkPadding()
        return bounds.inset(by: padding)
    }
}

internal class ColorPicker: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    
    @IBOutlet var colorPreviewImage: StackedImageView!
    @IBOutlet var lastColorsCollectionView: UICollectionView!
    @IBOutlet var colorPreviewContainer: UIView!
    @IBOutlet var colorPreviewText: UILabel!
    @IBOutlet var colorPreview: UIView!
    @IBOutlet var alphaPickerContainerView: UIView!
    @IBOutlet var brightnessPickerContainerView: UIView!
    @IBOutlet var slidersContainer: UIView!
    @IBOutlet var sliders: [GradientSlider]!
    @IBOutlet var inputs: [PaddedTextField]!
    @IBOutlet var alphaPickerCursor: UIImageView!
    @IBOutlet var brightnessPickerCursor: UIImageView!
    @IBOutlet var colorPickerContainerView: UIView!
    @IBOutlet var colorPickerCursor: UIImageView!
    @IBOutlet var brightnessPickerGradientView: GradientView!
    @IBOutlet var alphaPickerImage: UIImageView!
    @IBOutlet var alphaPickerGradientView: GradientView!
    @IBOutlet var colorPickerImage: UIImageView!
    
    @IBOutlet var recentlabel: UILabel!
    private var colorPickerDidConfirm = false
    weak var delegate: ColorPickerDelegate? = nil
    private static var lastColors: [UIColor] = []
    
    internal static var shouldUseHEX = false, shouldOptimiseHEX = false, shouldUseKeywords = false, maxColors = 10
    private static var didUserDefaultsIsLoaded = false
    internal var presentedAsPopover = false
    internal var presentedModally = false
    internal var pushedIntoViewController = false
    
    var red: CGFloat = 0,
    green: CGFloat = 0,
    blue: CGFloat = 0,
    hue: CGFloat = 0,
    brightness: CGFloat = 0,
    saturation: CGFloat = 0,
    alpha: CGFloat = 0;
    
    var currentColor: UIColor? = nil;
    
    internal static func getLastColors() -> [UIColor]{
        if(lastColors.isEmpty) {
            ColorPicker.readColorsFromMemory()
        }
        
        return lastColors
    }
    
    internal static func setLastColors(_ colors: [UIColor]) {
        ColorPicker.lastColors = colors
    }
    
    @discardableResult internal func setColorPickerDelegate(_ delegate: ColorPickerDelegate?) -> ColorPicker {
        self.delegate = delegate
        return self
    }
    @discardableResult internal func setInitialColor(_ color: UIColor?) -> ColorPicker {
        currentColor = color
        return self
    }
    
    override internal func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        alphaPickerGradientView?.updateConstraints()
        alphaPickerGradientView?.frame.size = (alphaPickerGradientView?.frame.size)!
    }
    
    func setupSliders()
    {
        sliders.forEach(){
            slider in
            slider.addTarget(self, action: #selector(ColorPicker.sliderValueDidChange(_ :)))
            slider.minValue = 0
            slider.maxValue = 255
        }
    }
    
    func addDoneButtonOnNumpads() {
        
        let keypadToolbar: UIToolbar = UIToolbar()
        
        keypadToolbar.items = [
            UIBarButtonItem(title: localize("ready"), style: UIBarButtonItem.Style.done, target: textField, action: #selector(resignFirstResponders)),
            UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        ]
        
        keypadToolbar.frame.size.height = 40
        // add a toolbar with a done button above the number pad
        inputs.forEach {input in input.inputAccessoryView = keypadToolbar}
    }
    
    @objc func resignFirstResponders(){
        inputs.forEach {input in input.resignFirstResponder()}
    }
    
    func setupGestureRecognizers(){
        
        let panPickerRecogniser = UIPanGestureRecognizer(target: self, action:#selector(ColorPicker.colorPickerImagePanRecognizerAction(_ : )))
        panPickerRecogniser.delegate = self
        colorPickerImage.addGestureRecognizer(panPickerRecogniser)
        
        let tapPickerRecogniser = UITapGestureRecognizer(target: self, action:#selector(ColorPicker.colorPickerImageTapRecognizerAction(_ : )))
        tapPickerRecogniser.delegate = self
        colorPickerImage.addGestureRecognizer(tapPickerRecogniser)
        
        let tapBrightnessRecogniser = UITapGestureRecognizer(target: self, action:#selector(ColorPicker.brightnessPickerImageTapRecognizerAction(_ : )))
        tapBrightnessRecogniser.delegate = self
        brightnessPickerContainerView.addGestureRecognizer(tapBrightnessRecogniser)
        
        let panBrightnessRecogniser = UIPanGestureRecognizer(target: self, action:#selector(ColorPicker.brightnessPickerImagePanRecognizerAction(_ : )))
        panBrightnessRecogniser.delegate = self
        brightnessPickerContainerView.addGestureRecognizer(panBrightnessRecogniser)
        
        let tapAlphaRecogniser = UITapGestureRecognizer(target: self, action:#selector(ColorPicker.alphaPickerImageTapRecognizerAction(_ : )))
        tapBrightnessRecogniser.delegate = self
        alphaPickerContainerView.addGestureRecognizer(tapAlphaRecogniser)
        
        let panAlphaRecogniser = UIPanGestureRecognizer(target: self, action:#selector(ColorPicker.alphaPickerImagePanRecognizerAction(_ : )))
        panBrightnessRecogniser.delegate = self
        alphaPickerContainerView.addGestureRecognizer(panAlphaRecogniser)
    }
    
    func doSomeCosmeticImprovements()
    {
        alphaPickerGradientView.clipsToBounds = true
        alphaPickerImage.clipsToBounds = true
        brightnessPickerGradientView.clipsToBounds = true
        alphaPickerImage.layer.cornerRadius = 7
        alphaPickerGradientView.layer.cornerRadius = 7
        brightnessPickerGradientView.layer.cornerRadius = 7
        
        colorPreviewContainer.layer.borderColor = UIColor(white: 0.6, alpha: 0.6).cgColor
        colorPreviewContainer.layer.borderWidth = 1
        colorPreviewContainer.layer.cornerRadius = 5.0
        colorPreviewContainer.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3).cgColor
        colorPreviewContainer.layer.shadowRadius = 5.0
        colorPreviewContainer.layer.shadowOpacity = 1.0
        colorPreviewContainer.layer.shadowOffset = CGSize(width: 0, height: 3)
        colorPreview.layer.cornerRadius = 5.0
        colorPreviewImage.clipsToBounds = true
        colorPreviewImage.layer.cornerRadius = 5.0
        
        
        
        let backButton = UIBarButtonItem(title: localize("ready"), style: .done, target: self, action: #selector(doneButtonAction))
        if(self.presentedAsPopover){
            self.navigationItem.rightBarButtonItem = backButton
            
        } else {
            let cancelButton = UIBarButtonItem(title: localize("cancel"), style: .plain, target: self, action: #selector(cancelButtonAction))
            
            self.navigationItem.rightBarButtonItem = cancelButton
            if(!pushedIntoViewController) {
                self.navigationItem.leftBarButtonItem = backButton
            }
        }
    }
    
    func setupLastColorsCollectionView(){
        lastColorsCollectionView.delegate = self
        lastColorsCollectionView.dataSource = self
    }
    
    static func readUserDefaults(){
        
        if(Defaults.object(forKey: "shouldUseHEX") != nil){
            ColorPicker.shouldUseHEX = Defaults.bool(forKey: "shouldUseHEX")
        } else {
            Defaults.set(true, forKey: "shouldUseHEX");
            ColorPicker.shouldUseHEX = true
        }
        if(Defaults.object(forKey: "shouldOptimiseHEX") != nil){
            ColorPicker.shouldOptimiseHEX = Defaults.bool(forKey: "shouldOptimiseHEX")
        } else {
            Defaults.set(true, forKey: "shouldOptimiseHEX");
            ColorPicker.shouldOptimiseHEX = true
        }
        if(Defaults.object(forKey: "shouldUseKeywords") != nil){
            ColorPicker.shouldUseKeywords = Defaults.bool(forKey: "shouldUseKeywords")
        } else {
            Defaults.set(true, forKey: "shouldUseKeywords");
            ColorPicker.shouldUseKeywords = true
        }
        
        let maxColors = Defaults.object(forKey: "colorMax")
        
        if(maxColors == nil)
        {
            Defaults.set(30, forKey: "colorMax")
        }
        ColorPicker.maxColors = (maxColors as? Int) ?? 30
        
        didUserDefaultsIsLoaded = true
    }
    
    private static func readColorsFromMemory() {
        if(!ColorPicker.didUserDefaultsIsLoaded)
        {
            ColorPicker.readUserDefaults()
        }
        
        var i = 0;
        
        while(true) {
            let key = "color\(i)"
            let color = Defaults.color(forKey: key)
            
            if(color == nil) {break}
            
            ColorPicker.lastColors.append(color!)
            
            i += 1
        }
        
        if(i == 0) {
            ColorPicker.lastColors = [UIColor.white, UIColor.clear, UIColor.red, UIColor.green, UIColor.blue, UIColor.magenta, UIColor.gray, UIColor.brown, UIColor.cyan, UIColor.black]
        }
    }
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        title = localize("colorpick")
        recentlabel.text = localize("recent")
        
        let parent = (self.navigationController as? ColorPickerNavigationController)
        
        if(parent != nil) {
            parent!.preferredContentSize = CGSize(width: 360, height: 550)
            self.delegate = parent!.colorPickerDelegate
            self.presentedModally = parent!.presentedModally
            self.presentedAsPopover = parent!.presentedAsPopover
        }
        
        alphaPickerGradientView?.layer.addSublayer(alphaPickerGradientView.gradientLayer)
        alphaPickerGradientView.backgroundColor = UIColor.clear
        
        NotificationCenter.default.addObserver(self, selector: #selector(ColorPicker.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ColorPicker.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ColorPicker.keyboardWillShow), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        
        
        brightnessPickerGradientView.gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        
        colorPickerContainerView.bringSubviewToFront(colorPickerCursor)
        
        drawColorSelectionBoard()
        setupGestureRecognizers()
        setupInputFields()
        setupSliders()
        setupLastColorsCollectionView()
        addDoneButtonOnNumpads()
        doSomeCosmeticImprovements()
        if(ColorPicker.lastColors.isEmpty) {
            ColorPicker.readColorsFromMemory()
        }
        
        lastColorsCollectionView.reloadData()
        setColor(color: parent?.initialColor ?? currentColor ?? ColorPicker.lastColors.first!)
    }
    
    @discardableResult static func present(inNavigationViewController: UINavigationController) -> ColorPicker {
        let vc = UIStoryboard(name: "Misc", bundle: nil)
            .instantiateViewController(withIdentifier: "ColorPicker") as! ColorPicker
        vc.presentedModally = false
        vc.presentedAsPopover = false
        vc.pushedIntoViewController = true
        
        inNavigationViewController.pushViewController(vc, animated: true)
        return vc
    }
    
    @discardableResult static func present(from: UIViewController, origin: UIView?, completion: (() -> Swift.Void)? = nil) -> ColorPickerNavigationController
    {
        let screenSize = UIScreen.main.bounds
        let storyboard : UIStoryboard = UIStoryboard(name: "Misc", bundle: nil)
        let minsize = min(screenSize.width, screenSize.height)
        
        let vc = storyboard.instantiateViewController(withIdentifier: "ColorPickerNavigationController") as! ColorPickerNavigationController
        vc.presentedModally = minsize >= 380
        
        if(origin != nil && minsize > 414){
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
    
    func setupInputFields()
    {
        inputs.forEach(){
            input in
            input.delegate = self
            input.addTarget(self, action: #selector(ColorPicker.textFieldValueDidChange(_:)), for: .editingChanged)
        }
    }
    
    func drawColorSelectionBoard(){
        
        let width = 128
        let size = CGSize(width:width, height: width)
        let opaque = false
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        var hue: CGFloat = 0.0
        let deltaHue = CGFloat(1.0 / Double(width))
        for x in 0...width
        {
            let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 0)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0;
            color.getRed(&red, green: &green, blue: &blue, alpha: nil)
            hue += deltaHue;
            for y in 0...width
            {
                context.setFillColor(UIColor(red: (1 - ((1 - red) * deltaHue * CGFloat(y))), green: (1 - ((1 - green) * deltaHue * CGFloat(y))), blue: (1 - ((1 - blue) * deltaHue * CGFloat(y))), alpha: 1.0).cgColor)
                context.fill(CGRect(x:x,y:y,width:1,height:1))
            }
        }
        
        colorPickerImage?.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    internal static func getColorNameBy(color: UIColor) -> String
    {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return getColorNameBy(red: Int(red * 255), green: Int(green * 255), blue: Int(blue * 255), alpha: alpha)
    }
    
    internal static func getColorNameBy(red: Int, green: Int, blue: Int, alpha: CGFloat) -> String
    {
        if(!ColorPicker.didUserDefaultsIsLoaded) {
            ColorPicker.readUserDefaults()
        }
        
        let isTransparent = alpha <= 0.995;
        if(!isTransparent)
        {
            if(shouldUseKeywords)
            {
                if(red == 0) {
                    if(green == 0) {
                        if(blue == 0) {
                            // #000000 - black
                            return "black"
                        } else if(blue == 255) {
                            // #0000FF - blue
                            return "blue"
                        }
                    } else if(green == 255) {
                        if(blue == 0) {
                            // #00FF00 - lime
                            return "lime"
                        } else if(blue == 255) {
                            // #00FFFF - aqua
                            return "aqua"
                        }
                    }
                } else if(red == 255) {
                    if(green == 0) {
                        if(blue == 0) {
                            // #FF0000 - red
                            return "red"
                        } else if(blue == 255) {
                            // #FF00FF - magenta
                            return "magenta"
                        }
                    } else if(green == 255) {
                        if(blue == 0) {
                            // #FFFF00 - yellow
                            return "yellow"
                        } else if(blue == 255) {
                            // #FFFFFF - white
                            return "white"
                        }
                    }
                }
            }
            
            if(shouldUseHEX)
            {
                var redhex = String(red, radix: 16, uppercase: false)
                var greenhex = String(green, radix: 16, uppercase: false)
                var bluehex = String(blue, radix: 16, uppercase: false)
                
                let redhexcount = redhex.count
                let greenhexcount = greenhex.count
                let bluehexcount = bluehex.count
                
                if(shouldOptimiseHEX && (red == 0 || red % 17 == 0) && (green == 0 || green % 17 == 0) && (blue == 0 || blue % 17 == 0)) {
                    redhex = String(redhex.prefix(1))
                    greenhex = String(greenhex.prefix(1))
                    bluehex = String(bluehex.prefix(1))
                } else if(redhexcount == 1 || greenhexcount == 1 || bluehexcount == 1)
                {
                    if redhexcount == 1 { redhex = "0" + redhex }
                    if greenhexcount == 1 { greenhex = "0" + greenhex }
                    if bluehexcount == 1 { bluehex = "0" + bluehex }
                }
                
                return "#" + redhex + greenhex + bluehex
            }
        }
        
        if(isTransparent)
        {
            if(alpha == 0.0 && shouldUseKeywords) { return "transparent" }
            
            var _alpha = String(describing: round(alpha * 100) / 100)
            _alpha = String(_alpha.suffix(_alpha.count - 1))
            return "rgba(\(red),\(green),\(blue),\(_alpha))"
        } else {
            return "rgb(\(red),\(green),\(blue))"
        }
    }
    
    func updateColorName(){
        self.colorPreviewText.text = ColorPicker.getColorNameBy(red: Int(red * 255), green: Int(green * 255), blue: Int(blue * 255), alpha: alpha)
    }
    
    func colorDidChange(){
        colorPreview.backgroundColor = currentColor
        
        updateColorName()
        
        if(self.presentedModally){
            delegate?.colorPicker?(colorDidChange: self)
        }
    }
    
    internal override func viewDidDisappear(_ animated: Bool) {
        if(pushedIntoViewController && !colorPickerDidConfirm) {
            onSuccessfulDismiss()
        }
    }
    
    internal override func viewWillDisappear(_ animated: Bool) {
        if(colorPickerDidConfirm){ return }
        delegate?.colorPicker?(colorPickerWillDisappear: self)
    }
    
    func setColor(color: UIColor, animated: Bool = false)
    {
        guard currentColor != color else {
            return
        }
        currentColor = color
        
        currentColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        currentColor?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        
        CATransaction.begin()
        
        if(!animated){
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        } else {
            CATransaction.setValue(0.3, forKey: kCATransactionAnimationDuration)
        }
        
        alphaPickerGradientView.gradientLayer.colors = [UIColor(red: red, green: green, blue: blue, alpha: 1.0).cgColor, UIColor.clear.cgColor]
        brightnessPickerGradientView.backgroundColor = UIColor(hue: hue, saturation: saturation, brightness: 1.0, alpha: 1.0)
        
        CATransaction.commit()
        
        UIView.animate(withDuration: animated ? 0.3 : 0.0)
        {
            self.brightnessPickerCursor.frame.origin.y = (1 - self.brightness) * (self.brightnessPickerGradientView.frame.height - 10)
            self.alphaPickerCursor.frame.origin.y = (1 - self.alpha) * (self.alphaPickerImage.frame.size.height - 10)
            
            self.sliders[0].value = Float(self.red * 255)
            self.sliders[1].value = Float(self.green * 255)
            self.sliders[2].value = Float(self.blue * 255)
            self.inputs[0].text = String(Int(self.red * 255))
            self.inputs[1].text = String(Int(self.green * 255))
            self.inputs[2].text = String(Int(self.blue * 255))
            
            self.colorPickerCursor.frame.origin.x = self.hue * self.colorPickerImage.frame.width - 10
            self.colorPickerCursor.frame.origin.y = self.saturation * self.colorPickerImage.frame.height - 10
        }
        
        for i in 0...2 {
            updateSliderGradientColorsWithId(i, animated: animated)
        }
        
        self.colorDidChange()
    }
    
    @objc func colorPickerImagePanRecognizerAction(_ sender: UIPanGestureRecognizer){
        let coord = sender.location(in: colorPickerImage)
        onColorPickerAction(
            x: max(min(coord.x,colorPickerImage.frame.width),0),
            y: max(min(coord.y,colorPickerImage.frame.height),0)
        )
        colorDidChange()
    }
    
    @objc func colorPickerImageTapRecognizerAction(_ sender: UIPanGestureRecognizer){
        let coord = sender.location(in: colorPickerImage)
        UIView.animate(withDuration: 0.3){
            self.onColorPickerAction(x: max(min(coord.x,self.colorPickerImage.frame.width),0), y: max(min(coord.y,self.colorPickerImage.frame.height),0), animated: true)
            self.colorDidChange()
        }
    }
    
    func animateTextFieldTo(label: UITextField, from startValue: Int? = nil, to endValue: Int) {
        
        let startValue: Int = startValue ?? Int(label.text!) ?? 0
        if(startValue == endValue){return}
        
        var sleepTime = Int64(300000 / Double(abs(endValue - startValue)))
        var step = 1
        
        while sleepTime < 20000 {
            sleepTime *= 2
            step *= 2
        }
        var bornTS = sleepTime + Int64(Date.timeIntervalSinceReferenceDate * 1000000)
        
        DispatchQueue(label: "easyhtml.colorpicker.animationqueue").async {
            var do_break = false
            let range = startValue < endValue ? stride(from: startValue + 1, to: endValue + 1, by: step) : stride(from: startValue - 1, to: endValue - 1, by: -step)
            var last = "\(startValue)";
            for i in range {
                DispatchQueue.main.sync {
                    if(label.text != last)
                    {
                        do_break = true
                        return;
                    }
                    last = "\(i)"
                    label.text = last
                }
                if(do_break){return}
                
                let currentSleepTime = bornTS - Int64(Date.timeIntervalSinceReferenceDate * 1000000)
                if(currentSleepTime > 0){usleep(UInt32(currentSleepTime))}
                
                bornTS += sleepTime
            }
            DispatchQueue.main.sync { label.text = "\(endValue)" }
        }
    }
    
    func onColorPickerAction(x: CGFloat, y: CGFloat, animated: Bool = false) {
        hue = CGFloat(x / colorPickerImage.frame.width);
        saturation = CGFloat(y / colorPickerImage.frame.height);
        
        currentColor = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        
        currentColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        colorPickerCursor.frame.origin.x = x - 10
        colorPickerCursor.frame.origin.y = y - 10
        
        brightnessPickerGradientView.backgroundColor = UIColor(hue: hue, saturation: saturation, brightness: 1.0, alpha: 1.0)
        
        CATransaction.begin()
        if(animated)
        {
            animateTextFieldTo(label: inputs[0], to: Int(red * 255))
            animateTextFieldTo(label: inputs[1], to: Int(green * 255))
            animateTextFieldTo(label: inputs[2], to: Int(blue * 255))
            
            CATransaction.setValue(0.3, forKey: kCATransactionAnimationDuration)
        } else {
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            inputs[0].text = String(Int(red * 255))
            inputs[1].text = String(Int(green * 255))
            inputs[2].text = String(Int(blue * 255))
        }
        alphaPickerGradientView.gradientLayer.colors = [UIColor(red: red, green: green, blue: blue, alpha: 1.0).cgColor, UIColor.clear.cgColor]
        
        CATransaction.commit()
        
        sliders[0].value = Float(red * 255)
        sliders[1].value = Float(green * 255)
        sliders[2].value = Float(blue * 255)
        
        for i in 0...2 {
            updateSliderGradientColorsWithId(i, animated: animated)
        }
    }
    
    @objc func brightnessPickerImagePanRecognizerAction(_ sender: UIPanGestureRecognizer){
        let coord = sender.location(in: colorPickerImage)
        onBrightnessPickerAction(
            y: max(min(coord.y,colorPickerImage.frame.height),0)
        )
        colorDidChange()
    }
    @objc func brightnessPickerImageTapRecognizerAction(_ sender: UITapGestureRecognizer){
        let coord = sender.location(in: colorPickerImage)
        UIView.animate(withDuration: 0.3){
            self.onBrightnessPickerAction(
                y: max(min(coord.y,self.colorPickerImage.frame.height),0),
                animated: true
            )
            self.colorDidChange()
        }
    }
    
    func onBrightnessPickerAction(y: CGFloat, animated: Bool = false) {
        brightness = 1 - CGFloat(y / colorPickerImage.frame.height);
        
        currentColor = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        
        currentColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        brightnessPickerCursor.frame.origin.y = y / brightnessPickerGradientView.frame.height * (brightnessPickerGradientView.frame.height - 10)
        
        CATransaction.begin()
        if(animated)
        {
            animateTextFieldTo(label: inputs[0], to: Int(red * 255))
            animateTextFieldTo(label: inputs[1], to: Int(green * 255))
            animateTextFieldTo(label: inputs[2], to: Int(blue * 255))
            
            CATransaction.setValue(0.3, forKey: kCATransactionAnimationDuration)
        } else {
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            inputs[0].text = String(Int(red * 255))
            inputs[1].text = String(Int(green * 255))
            inputs[2].text = String(Int(blue * 255))
        }
        
        alphaPickerGradientView.gradientLayer.colors = [UIColor(red: red, green: green, blue: blue, alpha: 1.0).cgColor, UIColor.clear.cgColor]
        
        CATransaction.commit()
        
        sliders[0].value = Float(red * 255)
        sliders[1].value = Float(green * 255)
        sliders[2].value = Float(blue * 255)
        
        for i in 0...2 {
            updateSliderGradientColorsWithId(i, animated: animated)
        }
    }
    
    @objc func alphaPickerImagePanRecognizerAction(_ sender: UIPanGestureRecognizer){
        let coord = sender.location(in: colorPickerImage)
        onAlphaPickerAction(y: max(min(coord.y,colorPickerImage.frame.height),0))
        colorDidChange()
    }
    @objc func alphaPickerImageTapRecognizerAction(_ sender: UITapGestureRecognizer){
        let coord = sender.location(in: colorPickerImage)
        UIView.animate(withDuration: 0.3){
            self.onAlphaPickerAction(y: max(min(coord.y,self.colorPickerImage.frame.height),0), animated: true)
            self.colorDidChange()
        }
    }
    
    func onAlphaPickerAction(y: CGFloat, animated: Bool = false) {
        alpha = 1 - CGFloat(y / colorPickerImage.frame.height);
        
        currentColor = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        
        alphaPickerCursor.frame.origin.y = y / alphaPickerGradientView.frame.height * (alphaPickerGradientView.frame.height - 10)
        
        colorDidChange()
    }
    
    internal func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
    {
        let str = (textField.text! + string)
        
        if str.count > 3 {
            textField.text = String(str.prefix(3))
            
            return false
        }
        
        return true
    }
    
    @objc func textFieldValueDidChange(_ textField: UITextField)
    {
        let value = max(min(Float(textField.text!) ?? 0,255),0)
        let inputNum = inputs.firstIndex(of: textField as! PaddedTextField)!
        
        UIView.animate(withDuration: 0.3){
            self.sliders[self.inputs.firstIndex(of: textField as! PaddedTextField)!].value = value
            self.inputUpdatedWith(id: inputNum, value: value, animated: true)
        }
        
        colorDidChange()
    }
    
    internal func textFieldDidEndEditing(_ textField: UITextField) {
        textField.text = String(max(min(Int(textField.text!) ?? 0,255),0))
    }
    
    @objc func sliderValueDidChange(_ slider: GradientSlider)
    {
        let sliderNum = sliders.firstIndex(of: slider)!
        inputs[sliderNum].text = String(Int(slider.value))
        
        inputUpdatedWith(id: sliderNum, value: slider.value)
        colorDidChange()
    }
    
    func updateSliderGradientColorsWithId(_ i: Int, animated: Bool = false)
    {
        sliders[i].setColors(
            first: UIColor(red: i == 0 ? 0.0 : red, green: i == 1 ? 0.0 : green, blue: i == 2 ? 0.0 : blue, alpha: 1.0),
            second: UIColor(red: i == 0 ? 1.0 : red, green: i == 1 ? 1.0 : green, blue: i == 2 ? 1.0 : blue, alpha: 1.0)
            , animated: animated)
    }
    
    func inputUpdatedWith(id: Int, value: Float, animated: Bool = false)
    {
        let intValue = Int(value)
        if(id == 0){
            if(intValue == Int(red * 255)) { return };
            red = CGFloat(value / 255.0)
        }
        else if(id == 1){
            if(intValue == Int(green * 255)) { return };
            green = CGFloat(value / 255.0)
        }
        else {
            if(intValue == Int(blue * 255)) { return };
            blue = CGFloat(value / 255.0)
        }
        
        for i in 0...2 {
            if(i == id){ continue }
            
            updateSliderGradientColorsWithId(i, animated: animated)
        }
        
        currentColor = UIColor(red: red, green: green, blue: blue, alpha: alpha)
        
        currentColor?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        
        colorPickerCursor.frame.origin.x = hue * colorPickerImage.frame.width - 10
        colorPickerCursor.frame.origin.y = saturation * colorPickerImage.frame.height - 10
        
        brightnessPickerGradientView.backgroundColor = UIColor(hue: hue, saturation: saturation, brightness: 1.0, alpha: 1.0)
        brightnessPickerCursor.frame.origin.y = (1 - brightness) * (brightnessPickerGradientView.frame.height - 10)
        
        CATransaction.begin()
        
        if(!animated){
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        } else {
            CATransaction.setValue(0.3, forKey: kCATransactionAnimationDuration)
        }
        alphaPickerGradientView.gradientLayer.colors = [UIColor(red: red, green: green, blue: blue, alpha: 1.0).cgColor, UIColor.clear.cgColor]
        
        CATransaction.commit()
    }
    
    @objc func keyboardWillHide(sender: NSNotification) {
        if self.presentedModally {
            return
        }
        
        self.view.transform = .identity
    }
    
    private var transform: CGFloat = 0 {
        didSet {
            self.view.transform.ty = -transform
        }
    }
    
    @objc func keyboardWillShow(sender: NSNotification) {
        if self.presentedModally {
            return
        }
        
        let userInfo = sender.userInfo!
        var offset: CGSize = (userInfo[UIResponder.keyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue.size
        
        // Проверка на то, откреплена ли клавиатура от низа экрана
        // такое может быть на iPadOS
        
        if offset.width < UIScreen.main.bounds.width {
            offset.height = 0
        }
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber
        
        let slidersContainerBounds = slidersContainer.convert(slidersContainer.bounds, to: UIApplication.shared.delegate?.window!?.rootViewController?.view)
        
        var y = UIScreen.main.bounds.height - slidersContainerBounds.maxY - transform
        
        if(slidersContainerBounds.minY < 40)
        {
            y += 12
        }
        
        y -= offset.height
        
        y = min(0, y);
        
        UIView.animate(withDuration: animationDuration?.doubleValue ?? 0.1, animations: { () -> Void in
            self.transform = -y
        })
    }
    
    internal func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = lastColorsCollectionView.dequeueReusableCell(withReuseIdentifier: "color", for: indexPath) as! ColorCollectionReusableCell
        cell.colorView.backgroundColor = ColorPicker.lastColors[indexPath.row]
        cell.layer.shadowColor = UIColor(white: 0.0, alpha: 0.4).cgColor
        cell.layer.shadowRadius = 2
        cell.layer.shadowOpacity = 1
        cell.layer.shadowOffset = CGSize(width:0, height: 3)
        cell.layer.borderWidth = 1
        cell.layer.borderColor = UIColor(white: 0.6, alpha: 0.4).cgColor
        cell.clipsToBounds = false
        
        return cell
    }
    
    internal func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        setColor(color: ColorPicker.lastColors[indexPath.row], animated: true)
    }
    
    internal func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ColorPicker.lastColors.count;
    }
    
    internal func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func writeLastColors(){
        
        var i = 0
        
        for color in ColorPicker.lastColors {
            Defaults.set(color: color, forKey: "color\(i)")
            i += 1
        }
        
        deleteOverflowingColors(i)
    }
    
    func deleteOverflowingColors(_ i: Int = -1){
        var i = i
        if(i == -1) {i = ColorPicker.maxColors}
        
        var key = ""
        while(true)
        {
            key = "color\(i)"
            if(Defaults.object(forKey: key) == nil) {break;}
            Defaults.removeObject(forKey: key)
        }
    }
    
    func onSuccessfulDismiss() {
        let index = ColorPicker.lastColors.firstIndex(of: currentColor!)
        
        self.colorPickerDidConfirm = true
        delegate?.colorPicker?(colorPickerDidConfirm: self)
        
        if(index != nil)
        {
            ColorPicker.lastColors.remove(at: index!)
        }
        ColorPicker.lastColors.insert(currentColor!, at: 0)
        if(ColorPicker.lastColors.count > ColorPicker.maxColors)
        {
            ColorPicker.lastColors = Array(ColorPicker.lastColors.prefix(ColorPicker.maxColors))
        }
        writeLastColors()
    }
    
    @objc func doneButtonAction(_ sender: UIBarButtonItem){
        onSuccessfulDismiss()
        
        if(pushedIntoViewController) {
            navigationController?.popViewController(animated: true)
            return
        }
        dismiss(animated: true, completion: nil)
    }
    
    @objc func cancelButtonAction(_ sender: UIBarButtonItem)
    {
        delegate?.colorPicker?(colorPickerDidCancel: self)
        colorPickerDidConfirm = true
        if(pushedIntoViewController) {
            navigationController?.popViewController(animated: true)
            return
        }
        dismiss(animated: true, completion: nil)
    }
    
    override internal func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "openSettings")
        {
            (segue.destination as! ColorPickerSettingsViewController).colorPicker = self
        }
    }
    
    override internal func viewDidLayoutSubviews() {
        self.colorPickerCursor.frame.origin.x = self.hue * self.colorPickerImage.frame.width - 10
        self.colorPickerCursor.frame.origin.y = self.saturation * self.colorPickerImage.frame.height - 10
        self.brightnessPickerCursor.frame.origin.y = (1 - self.brightness) * (self.brightnessPickerGradientView.frame.height - 10)
        self.alphaPickerCursor.frame.origin.y = (1 - self.alpha) * (self.alphaPickerImage.frame.size.height - 10)
    }
    
    override internal func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) {
            _ in
            self.viewDidLayoutSubviews()
            
        }
    }
}

internal class ColorCollectionReusableCell: UICollectionViewCell {
    @IBOutlet var colorView: UIView!
}

internal class ColorPickerNavigationController: ThemeColoredNavigationController {
    var presentedAsPopover = false
    var presentedModally = true
    weak var colorPickerDelegate: ColorPickerDelegate?
    var initialColor: UIColor?
    
    @discardableResult func setDelegate(delegate: ColorPickerDelegate?) -> ColorPickerNavigationController {
        colorPickerDelegate = delegate
        return self
    }
    
    @discardableResult func setColorPickerInitialColor(_ color: UIColor?) -> ColorPickerNavigationController {
        initialColor = color
        return self
    }
}

@objc internal protocol ColorPickerDelegate
{
    @objc optional func colorPicker(colorPickerDidCancel sender: ColorPicker)
    @objc optional func colorPicker(colorDidChange sender: ColorPicker)
    @objc optional func colorPicker(colorPickerWillDisappear sender: ColorPicker)
    @objc optional func colorPicker(colorPickerDidConfirm sender: ColorPicker)
}
