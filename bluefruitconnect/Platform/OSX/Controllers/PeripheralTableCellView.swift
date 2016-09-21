//
//  PeripheralTableCellView.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class PeripheralTableCellView: NSTableCellView {

    @IBOutlet weak var rssiImageView: NSImageView!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var subtitleTextField: NSTextField!
    @IBOutlet weak var connectButton: NSButton!
    
    var onClickConnectAction : (() -> ())?

    @IBAction func onClickConnectAction(sender: AnyObject) {
        onClickConnectAction?()
    }

}
