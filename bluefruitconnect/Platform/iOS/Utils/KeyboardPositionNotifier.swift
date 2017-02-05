//
//  KeyboardPositionNotifier.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

protocol KeyboardPositionNotifierDelegate: class {
    func onKeyboardPositionChanged(_ keyboardFrame : CGRect, keyboardShown : Bool)
}

class KeyboardPositionNotifier: NSObject {
    
    weak var delegate : KeyboardPositionNotifierDelegate?

    override init() {
        super.init()
        registerKeyboardNotifications(true)
    }
    
    deinit {
        registerKeyboardNotifications(false)
    }
    
    func registerKeyboardNotifications(_ enable : Bool) {
        let notificationCenter = NotificationCenter.default
        if (enable) {
            notificationCenter.addObserver(self, selector: #selector(KeyboardPositionNotifier.keyboardWillBeShown(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
            notificationCenter.addObserver(self, selector: #selector(KeyboardPositionNotifier.keyboardWillBeHidden(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        } else {
            notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
            notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        }
    }
    
    func keyboardWillBeShown(_ notification : Notification) {
        var info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
       
        keyboardPositionChanged(keyboardFrame, keyboardShown: true)
    }
    
    func keyboardWillBeHidden(_ notification : Notification) {
       keyboardPositionChanged(CGRect.zero, keyboardShown: false)
    }
    
    func keyboardPositionChanged(_ keyboardFrame : CGRect, keyboardShown : Bool) {
        delegate?.onKeyboardPositionChanged(keyboardFrame, keyboardShown: keyboardShown)
    }
}
