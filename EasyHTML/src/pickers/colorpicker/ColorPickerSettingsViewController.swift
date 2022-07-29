//
//  ColorPickerSettingsViewController.swift
//  EasyHTML
//
//  Created by Артем on 16/03/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

internal class ColorPickerSettingsTableSwitchCell: UITableViewCell {
    @IBOutlet var label: UILabel!
    @IBOutlet var switcher: UISwitch!
}

internal class ColorPickerSettingsResetCell: UITableViewCell {
    @IBOutlet var button: UIButton!


    internal override func didMoveToWindow() {
        button.setTitle(localize("reset"), for: .normal)
    }
}

internal class ColorPickerSettingsTableSliderCell: UITableViewCell {
    @IBOutlet var min: UILabel!
    @IBOutlet var max: UILabel!
    @IBOutlet var slider: UISlider!
}

internal class ColorPickerSettingsViewController: AlternatingColorTableView {

    var switches = [UISwitch]()
    var lastColorsSliderCell: LabeledSliderCell?

    var colorPicker: ColorPicker?

    override internal func viewDidLoad() {
        tableView.dataSource = self
        title = localize("preferences")

        tableView.register(SwitchCell.self, forCellReuseIdentifier: "label")
        tableView.register(LabeledSliderCell.self, forCellReuseIdentifier: "slider")

        updateStyle()
    }

    @objc func switchAction(_ sender: UISwitch) {

        shouldCompressHexCell?.switcher.setOn(sender.isOn, animated: true)
        UIView.animate(withDuration: 0.25) {
            self.shouldCompressHexCell?.alpha = sender.isOn ? 1.0 : 0.5
            self.shouldCompressHexCell?.switcher.isEnabled = sender.isOn
        }
    }

    @objc func sliderValueDidChange(_ sender: UISlider) {
        lastColorsSliderCell?.maxLabel.text = "\(Int(sender.value))"
    }

    override internal func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 0) {
            return localize("colorcode")
        }
        if (section == 1) {
            return localize("recentcolorsnumber")
        }
        return localize("reset")
    }

    override internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if (indexPath.section == 0) {
            let _switch: UISwitch!

            if indexPath.row == 1 && !(shouldUseHexCell?.switcher.isOn ?? ColorPicker.shouldUseHEX) {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }

            switch indexPath.row {
            case 0: _switch = shouldUseHexCell?.switcher
            case 1: _switch = shouldCompressHexCell?.switcher
            case 2: _switch = shouldUseColorKeywordsCell?.switcher
            default: _switch = nil
            }

            if _switch != nil {
                _switch.setOn(!_switch.isOn, animated: true)
                if indexPath.row == 0 {
                    switchAction(_switch)
                }
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override internal func numberOfSections(in tableView: UITableView) -> Int {
        3
    }

    override internal func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        false
    }

    override internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (section == 0) {
            return 3
        } else {
            return 1
        }
    }

    private var shouldUseHexCell: SwitchCell?
    private var shouldCompressHexCell: SwitchCell?
    private var shouldUseColorKeywordsCell: SwitchCell?
    private let font = UIFont.systemFont(ofSize: 14)

    override internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if (indexPath.section == 0) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "label") as! SwitchCell

            switch (indexPath.row) {
            case 0:

                if shouldUseHexCell != nil {
                    return shouldUseHexCell!
                }

                cell.label.text = localize("useHEX")
                cell.switcher.isOn = ColorPicker.shouldUseHEX
                cell.label.textColor = userPreferences.currentTheme.cellTextColor
                cell.label.font = font

                if cell.switcher.actions(forTarget: self, forControlEvent: .valueChanged)?.isEmpty ?? true {
                    cell.switcher.addTarget(self, action: #selector(switchAction), for: .valueChanged)
                }

                shouldUseHexCell = cell

                break;
            case 1:

                if shouldCompressHexCell != nil {
                    return shouldCompressHexCell!
                }

                cell.label.text = localize("compressHEX")
                cell.label.textColor = userPreferences.currentTheme.cellTextColor
                cell.switcher.isOn = ColorPicker.shouldUseHEX && ColorPicker.shouldOptimiseHEX
                cell.switcher.isEnabled = ColorPicker.shouldUseHEX
                cell.label.font = font

                shouldCompressHexCell = cell

                break;
            default:

                if shouldUseColorKeywordsCell != nil {
                    return shouldUseColorKeywordsCell!
                }

                cell.label.text = localize("usecolorkeywords")
                cell.label.textColor = userPreferences.currentTheme.cellTextColor
                cell.switcher.isOn = ColorPicker.shouldUseKeywords
                cell.label.font = font

                shouldUseColorKeywordsCell = cell

                break;
            }

            return cell

        } else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "slider") as! LabeledSliderCell
            cell.maxLabel.text = "\(ColorPicker.maxColors)"
            cell.minLabel.text = "5"
            cell.maxLabel.textColor = userPreferences.currentTheme.secondaryTextColor
            cell.minLabel.textColor = userPreferences.currentTheme.secondaryTextColor
            cell.slider.minimumValue = 5
            cell.slider.maximumValue = 50
            cell.slider.value = Float(ColorPicker.maxColors)
            lastColorsSliderCell = cell

            if cell.slider.actions(forTarget: self, forControlEvent: .valueChanged)?.isEmpty ?? true {
                cell.slider.addTarget(self, action: #selector(sliderValueDidChange), for: .valueChanged)
            }

            return cell
        } else {
            return tableView.dequeueReusableCell(withIdentifier: "reset")!
        }
    }

    override internal func viewWillDisappear(_ animated: Bool) {

        ColorPicker.shouldUseHEX = shouldUseHexCell?.switcher.isOn ?? ColorPicker.shouldUseHEX
        ColorPicker.shouldOptimiseHEX = shouldCompressHexCell?.switcher.isOn ?? ColorPicker.shouldOptimiseHEX
        ColorPicker.shouldUseKeywords = shouldUseColorKeywordsCell?.switcher.isOn ?? ColorPicker.shouldUseKeywords

        if let value = lastColorsSliderCell?.slider.value {
            ColorPicker.maxColors = Int(value)
        }

        Defaults.set(ColorPicker.shouldUseHEX, forKey: "shouldUseHEX")
        Defaults.set(ColorPicker.shouldOptimiseHEX, forKey: "shouldOptimiseHEX")
        Defaults.set(ColorPicker.shouldUseKeywords, forKey: "shouldUseKeywords")
        Defaults.set(ColorPicker.maxColors, forKey: "colorMax")

        colorPicker!.updateColorName()
        colorPicker!.deleteOverflowingColors()
        ColorPicker.setLastColors(Array(ColorPicker.getLastColors().prefix(ColorPicker.maxColors)))
        colorPicker!.lastColorsCollectionView.reloadData()
    }

    @IBAction internal func resetButtonAction(_ sender: UIButton) {
        func delete(action: UIAlertAction) -> Void {
            ColorPicker.setLastColors([colorPicker!.currentColor!])
            colorPicker!.deleteOverflowingColors(1)
        }

        let deleteAlert = UIAlertController(title: localize("resetquestion"), message: localize("cannotbeundone"), preferredStyle: UIAlertController.Style.actionSheet)
        deleteAlert.addAction(UIAlertAction(title: localize("reset"), style: UIAlertAction.Style.destructive, handler: delete))
        deleteAlert.addAction(UIAlertAction(title: localize("cancel"), style: UIAlertAction.Style.cancel, handler: nil))

        deleteAlert.popoverPresentationController?.sourceRect = sender.frame

        present(deleteAlert, animated: true, completion: nil)
    }
}
