//
//  NeopixelTypeValueTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 19/04/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

protocol NeopixelTypeValueTableViewCellDelegate: class {
    func onSetValue(_ value: UInt16)
}

class NeopixelTypeValueTableViewCell: UITableViewCell {

    // UI
    @IBOutlet weak var valueTextField: UITextField!
    @IBOutlet weak var doneButton: StyledButton!
    
    // Data
    weak var delegate: NeopixelTypeValueTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
//        doneButton.enabled = false
//        valueTextField.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onClickSet(_ sender: AnyObject) {
        
        if let type = typeFromInput(valueTextField.text) {
            self.delegate?.onSetValue(type)
        }
    }
    
    func typeFromInput(_ originalText: String?) -> UInt16? {
        var result: UInt16?
        if let text = originalText, let type = UInt16(text), !text.isEmpty && Int(text)!>=0 && Int(text)!  < 65535 {
                result = type
        }
        
        return result
    }
    
    func isInputValid(_ text: String?) -> Bool {
        return typeFromInput(text) != nil
    }
}

/*
extension NeopixelTypeValueTableViewCell: UITextFieldDelegate {
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        
        var textString: String?
        if let textFieldString = textField.text  {
            textString = textFieldString.stringByReplacingCharactersInRange(range.toStringRange(textFieldString), withString: string)
        }
        
        doneButton.enabled = isInputValid(textString)
        return true
    }
    /*
    func textFieldDidEndEditing(textField: UITextField) {
    }*/
}
 */
