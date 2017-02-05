//
//  PinTableCellView.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 18/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Cocoa

protocol PinTableCellViewDelegate: class {
    func onPinToggleCell(_ pinIndex: Int)
    func onPinModeChanged(_ mode: PinIOModuleManager.PinData.Mode, pinIndex: Int)
    func onPinDigitalValueChanged(_ value: PinIOModuleManager.PinData.DigitalValue, pinIndex: Int)
    func onPinAnalogValueChanged(_ value: Double, pinIndex: Int)
}


class PinTableCellView: NSTableCellView {

    // UI
    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var modeLabel: NSTextField!
    @IBOutlet weak var valueLabel: NSTextField!
    @IBOutlet weak var modeSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var digitalSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var valueSlider: NSSlider!
    
    // Data
    weak var delegate: PinTableCellViewDelegate?
    fileprivate var modesInSegmentedControl : [PinIOModuleManager.PinData.Mode] = []
    fileprivate var pinIndex: Int = 0
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    // MARK: - Setup
    func setPin(_ pin : PinIOModuleManager.PinData, pinIndex: Int) {
        self.pinIndex = pinIndex
        setupModeSegmentedControl(pin)
        digitalSegmentedControl.selectedSegment = pin.digitalValue.rawValue
        
        if (pin.digitalPinId == 5) {
            DLog("digital \(pin.digitalPinId) set: \(pin.digitalValue)")
        }
        
        valueSlider.doubleValue = Double(pin.analogValue)
        
        let analogName = pin.isAnalog ?", Analog \(pin.analogPinId)":""
        let fullName = "Pin \(pin.digitalPinId)\(analogName)"
        nameLabel.stringValue = fullName
        modeLabel.stringValue = PinIOModuleManager.stringForPinMode(pin.mode)
        
        var valueText: String!
        switch pin.mode {
        case .input:
            valueText = PinIOModuleManager.stringForPinDigitalValue(pin.digitalValue)
        case .output:
            valueText = PinIOModuleManager.stringForPinDigitalValue(pin.digitalValue)
        case .analog:
            valueText = String(pin.analogValue)
        case .pwm:
            valueText = String(pin.analogValue)
            
        default:
            valueText = ""
        }
        valueLabel.stringValue = valueText
        
        valueSlider.isHidden = pin.mode != .pwm
        digitalSegmentedControl.isHidden = pin.mode != .output
    }

    fileprivate func setupModeSegmentedControl(_ pin : PinIOModuleManager.PinData) {
        modesInSegmentedControl.removeAll()
        if pin.isDigital == true {
            modesInSegmentedControl.append(.input)
            modesInSegmentedControl.append(.output)
        }
        if pin.isAnalog {
            modesInSegmentedControl.append(.analog)
        }
        if pin.isPWM {
            modesInSegmentedControl.append(.pwm)
        }
        
        modeSegmentedControl.segmentCount = modesInSegmentedControl.count
        var i = 0
        for mode in modesInSegmentedControl {
            let modeName = PinIOModuleManager.stringForPinMode(mode)
            modeSegmentedControl.setLabel(modeName, forSegment: i)
            modeSegmentedControl.setWidth(100, forSegment: i)
            if pin.mode == mode {
                modeSegmentedControl.selectedSegment = i    // Select the mode we just added
            }
            
            i += 1
        }
    }

    // MARK: - Actions
    
    @IBAction func onClickToggleCell(_ sender: AnyObject) {
        delegate?.onPinToggleCell(pinIndex)
    }
    
    @IBAction func onModeChanged(_ sender: AnyObject) {
        delegate?.onPinModeChanged(modesInSegmentedControl[modeSegmentedControl.selectedSegment], pinIndex: pinIndex)
    }
    
    @IBAction func onDigitalChanged(_ sender: AnyObject) {
        if let selectedDigital = PinIOModuleManager.PinData.DigitalValue(rawValue: digitalSegmentedControl.selectedSegment) {
            delegate?.onPinDigitalValueChanged(selectedDigital, pinIndex: pinIndex)
        }
        else {
            DLog("Error onDigitalChanged with invalid value")
        }
    }
    
    @IBAction func onValueSliderChanged(_ sender: AnyObject) {
        delegate?.onPinAnalogValueChanged(valueSlider.doubleValue, pinIndex: pinIndex)
    }

}
