//
//  StatusViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class StatusViewController: NSViewController {

    @IBOutlet weak var statusTextField: NSTextField!
    
    var isAlertBeingPresented = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateStatus(_:)), name: NSNotification.Name(rawValue: StatusManager.StatusNotifications.DidUpdateStatus.rawValue), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: StatusManager.StatusNotifications.DidUpdateStatus.rawValue), object: nil)
    }
    
    func didUpdateStatus(_ notification: Notification) {
        
        let message = StatusManager.sharedInstance.statusDescription()
        
        DispatchQueue.main.async(execute: { [unowned self] in
            self.setText(message)
            //DLog("new status: \(message)")
            
            if (!self.isAlertBeingPresented) {       // Don't show a alert while another alert is being presented
                if let errorMessage = StatusManager.sharedInstance.errorDescription() {
                    self.isAlertBeingPresented = true
                    let alert = NSAlert()
                    alert.messageText = errorMessage
                    alert.addButton(withTitle: "Ok")
                    alert.alertStyle = .warning
                    alert.beginSheetModal(for: self.view.window!, completionHandler: { [unowned self] (modalResponse) -> Void in
                        self.isAlertBeingPresented = false
                        })
                }
            }
            })
    }
    
    func setText(_ text: String) {
        statusTextField.stringValue = text
    }
}
