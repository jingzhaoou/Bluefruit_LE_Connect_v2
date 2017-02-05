//
//  PinIOViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 16/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Cocoa

class PinIOViewController: NSViewController {

    // UI
    @IBOutlet weak var baseTableView: NSTableView!
    @IBOutlet weak var statusLabel: NSTextField!
    fileprivate var queryCapabilitiesAlert: NSAlert?

    // Data
    fileprivate let pinIO = PinIOModuleManager()
    fileprivate var tableRowOpen: Int?
    fileprivate var isQueryingFinished = false
    fileprivate var isTabVisible = false

    fileprivate var waitingDiscoveryAlert: NSAlert?
    var infoFinishedScanning = false {
        didSet {
            if infoFinishedScanning != oldValue {
                DLog("pinio infoFinishedScanning: \(infoFinishedScanning)")
                if infoFinishedScanning && waitingDiscoveryAlert != nil {
                    view.window?.endSheet(waitingDiscoveryAlert!.window)
                    waitingDiscoveryAlert = nil
                    startPinIo()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init
        pinIO.delegate = self
        baseTableView.rowHeight = 52
    }
    
    func uartIsReady(_ notification: Notification) {
        DLog("Uart is ready")
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        
        DispatchQueue.main.async(execute: { [unowned self] in
            self.setupFirmata()
            })
    }
    
    fileprivate func setupFirmata() {
        // Reset Firmata and query capabilities
        pinIO.reset()
        tableRowOpen = nil
        baseTableView.reloadData()
        startQueryCapabilitiesProcess()
    }
    
    fileprivate func startQueryCapabilitiesProcess() {
        guard isTabVisible else {
            return
        }
        
        guard !pinIO.isQueryingCapabilities() else {
            DLog("error: queryCapabilities called while querying capabilities")
            return
        }
        
        if queryCapabilitiesAlert != nil {
            DLog("Warning: Trying to create a new queryCapabilitiesAlert while the current one is not nil")
        }
        
        isQueryingFinished = false
        statusLabel.stringValue = "Querying capabilities..."
        
        // Show dialog
        if let window = self.view.window {
            let localizationManager = LocalizationManager.sharedInstance
            let alert = NSAlert()
            alert.messageText = localizationManager.localizedString("pinio_capabilityquery_querying_title")
            alert.addButton(withTitle: localizationManager.localizedString("dialog_cancel"))
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window, completionHandler: { [unowned self] (returnCode) -> Void in
                if returnCode == NSAlertFirstButtonReturn {
                    self.pinIO.endPinQuery(true)
                }
            }) 
            queryCapabilitiesAlert = alert
        }
        self.pinIO.queryCapabilities()
    }
    
    func defaultCapabilitiesAssumedDialog() {
        guard isTabVisible else {
            return
        }
        
        DLog("QueryCapabilities not found")
        
        if let window = self.view.window {
            let localizationManager = LocalizationManager.sharedInstance
            let alert = NSAlert()
            alert.messageText = localizationManager.localizedString("pinio_capabilityquery_expired_title")
            alert.informativeText = localizationManager.localizedString("pinio_capabilityquery_expired_message")
            alert.addButton(withTitle: localizationManager.localizedString("dialog_ok"))
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window, completionHandler: { (returnCode) -> Void in
                if returnCode == NSAlertFirstButtonReturn {
                }
            }) 
        }
    }

    @IBAction func onClickQuery(_ sender: AnyObject) {
        setupFirmata()
    }
}

// MARK: - DetailTab
extension PinIOViewController : DetailTab {
    func tabWillAppear() {
        pinIO.start()

        // Hack: wait a moment because a disconnect could call tabWillAppear just before disconnecting
        let dispatchTime: DispatchTime = DispatchTime.now() + Double(Int64(0.2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: { [weak self] in
            self?.startPinIo()
        })
    }
    
    func tabWillDissapear() {
        isTabVisible = false
        pinIO.stop()
    }
    
    func tabReset() {
        
    }

    fileprivate func startPinIo() {
        
        guard BleManager.sharedInstance.blePeripheralConnected != nil else {
            DLog("trying to make pionio tab visible while disconnecting")
            isTabVisible = false
            return
        }
        
        isTabVisible = true
        
        if !isQueryingFinished {
            // Start Uart Manager
            UartManager.sharedInstance.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
            
            if !infoFinishedScanning {
                DLog("pinio: waiting for info scanning...")
                if let window = view.window {
                    let localizationManager = LocalizationManager.sharedInstance
                    waitingDiscoveryAlert = NSAlert()
                    waitingDiscoveryAlert!.messageText = "Waiting for discovery to finish..."
                    waitingDiscoveryAlert!.addButton(withTitle: localizationManager.localizedString("dialog_cancel"))
                    waitingDiscoveryAlert!.alertStyle = .warning
                    waitingDiscoveryAlert!.beginSheetModal(for: window, completionHandler: { [unowned self] (returnCode) -> Void in
                        if returnCode == NSAlertFirstButtonReturn {
                            self.waitingDiscoveryAlert = nil
                            self.pinIO.endPinQuery(true)
                        }
                    }) 
                }
            }
            else if (UartManager.sharedInstance.isReady()) {
                setupFirmata()
            }
            else {
                DLog("Wait for uart to be ready to start PinIO setup")
                
                let notificationCenter =  NotificationCenter.default
                notificationCenter.addObserver(self, selector: #selector(PinIOViewController.uartIsReady(_:)), name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
            }
        }
    }
}


// MARK: - NSOutlineViewDataSource
extension PinIOViewController : NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return pinIO.pins.count
    }
    
}

// MARK: NSOutlineViewDelegate

extension PinIOViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let pin = pinIO.pins[row]
        
        let cell = tableView.make(withIdentifier: "PinCell", owner: self) as! PinTableCellView
        
        cell.setPin(pin, pinIndex:row)
        cell.delegate = self
        
        return cell;
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if let tableRowOpen = tableRowOpen, row == tableRowOpen {
            let pinOpen = pinIO.pins[tableRowOpen]
            return pinOpen.mode == .input || pinOpen.mode == .analog ? 106 : 130
        }
        else {
            return 52
        }
    }
    
    /*
    func tableViewSelectionDidChange(notification: NSNotification) {
        onPinToggleCell(baseTableView.selectedRow)
    }*/
}

// MARK:  PinTableCellViewDelegate
extension PinIOViewController : PinTableCellViewDelegate {
    func onPinToggleCell(_ pinIndex: Int) {
        // Change open row
        let previousTableRowOpen = tableRowOpen
        tableRowOpen = pinIndex == tableRowOpen ? nil: pinIndex
        
        // Animate changes
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current().duration = 0.25
        baseTableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: pinIndex))
        if let previousTableRowOpen = previousTableRowOpen, previousTableRowOpen >= 0 {
            baseTableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: previousTableRowOpen))
        }
        let rowRect = baseTableView.rect(ofRow: pinIndex)
        baseTableView.scrollToVisible(rowRect)
        NSAnimationContext.endGrouping()

    }
    func onPinModeChanged(_ mode: PinIOModuleManager.PinData.Mode, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setControlMode(pin, mode: mode)

        //DLog("pin \(pin.digitalPinId): mode: \(pin.mode.rawValue)")
        
        // Animate changes
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current().duration = 0.25
        baseTableView.reloadData(forRowIndexes: IndexSet(integer: pinIndex), columnIndexes: IndexSet(integer: 0))
        baseTableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: pinIndex))
        let rowRect = baseTableView.rect(ofRow: pinIndex)
        baseTableView.scrollToVisible(rowRect)
        NSAnimationContext.endGrouping()
        
    }
    func onPinDigitalValueChanged(_ value: PinIOModuleManager.PinData.DigitalValue, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setDigitalValue(pin, value: value)

        baseTableView.reloadData(forRowIndexes: IndexSet(integer: pinIndex), columnIndexes: IndexSet(integer: 0))
    }
    func onPinAnalogValueChanged(_ value: Double, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        if pinIO.setPMWValue(pin, value: Int(value)) {
            baseTableView.reloadData(forRowIndexes: IndexSet(integer: pinIndex), columnIndexes: IndexSet(integer: 0))
        }
    }
}

// MARK: - PinIOModuleManagerDelegate

extension PinIOViewController: PinIOModuleManagerDelegate {
    func onPinIODidEndPinQuery(_ isDefaultConfigurationAssumed: Bool) {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.isQueryingFinished = true
            self.baseTableView.reloadData()
            
            // Dismiss current alert
            if let window = self.view.window, let queryCapabilitiesAlert = self.queryCapabilitiesAlert {
                window.endSheet(queryCapabilitiesAlert.window)
                self.queryCapabilitiesAlert = nil
            }

            if isDefaultConfigurationAssumed {
                self.statusLabel.stringValue = "Default Arduino capabilities"
                self.defaultCapabilitiesAssumedDialog()
            }
            else {
                self.statusLabel.stringValue = "\(self.pinIO.digitalPinCount) digital pins. \(self.pinIO.analogPinCount) analog pins"
            }
            })
    }

    func onPinIODidReceivePinState() {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.baseTableView.reloadData()
            })
    }
}
