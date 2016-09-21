//
//  PeripheralListViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 22/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
import CoreBluetooth

class PeripheralListViewController: NSViewController {
    
    @IBOutlet weak var baseTableView: NSTableView!

    private let peripheralList = PeripheralList()
    var detailsViewController: DetailsViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup StatusManager
        StatusManager.sharedInstance.peripheralListViewController = self

        // Subscribe to Ble Notifications
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager2.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager2.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didDisconnectFromPeripheral(_:)), name: BleManager2.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
        
        notificationCenter.addObserver(self, selector: #selector(willConnectToPeripheral(_:)), name: BleManager2.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didConnectToPeripheral(_:)), name: BleManager2.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        notificationCenter.addObserver(self, selector: #selector(willDisconnectFromPeripheral(_:)), name: BleManager2.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
    }

    deinit {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: BleManager2.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: BleManager2.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: BleManager2.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
        
        notificationCenter.removeObserver(self, name: BleManager2.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: BleManager2.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        notificationCenter.removeObserver(self, name: BleManager2.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
    }
    
    
    // MARK: - Notifications
    
    func didDiscoverPeripheral(notification: NSNotification) {
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            
            // Reload data
            self.baseTableView.reloadData()
            
            // Select identifier if still available
            self.baseTableView.selectRowIndexes(NSIndexSet(index: self.baseTableView.selectedRow), byExtendingSelection: false)
            })
    }
    
    func didDisconnectFromPeripheral(notification: NSNotification) {
        

        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            
            if self.baseTableView.selectedRow >= 0 {
                let selectedBlePeripheralIdentifier = self.peripheralList.blePeripherals[self.baseTableView.selectedRow]
                let blePeripheral = BleManager2.sharedInstance.blePeripheralWithUuid(selectedBlePeripheralIdentifier)!
                if blePeripheral.state != .Disconnected {
                    // Unexpected disconnect if the row is still selected but the connected peripheral is nil and the time since the user selected a new peripheral is bigger than kMinTimeSinceUserSelection seconds
                    let kMinTimeSinceUserSelection = 1.0    // in secs
                    if self.peripheralList.elapsedTimeSinceSelection > kMinTimeSinceUserSelection {
                        self.baseTableView.deselectAll(nil)
                        
                        let localizationManager = LocalizationManager.sharedInstance
                        let alert = NSAlert()
                        alert.messageText = localizationManager.localizedString("peripherallist_peripheraldisconnected")
                        alert.addButtonWithTitle(localizationManager.localizedString("dialog_ok"))
                        alert.alertStyle = .WarningAlertStyle
                        alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
                    }
                }
                
                // Deselect cell in list
                if let disconnectedPeripheralUuid = notification.userInfo?["uuid"] as? String where selectedBlePeripheralIdentifier.caseInsensitiveCompare(disconnectedPeripheralUuid) == .OrderedSame {
                    self.baseTableView.deselectAll(nil)
                }
            }
            })
    }
    
    func willConnectToPeripheral(notification: NSNotification) {
        updateConnectionStatusFromNotification(notification)
    }
    
    func didConnectToPeripheral(notification: NSNotification) {
        updateConnectionStatusFromNotification(notification)
    }
    
    func willDisconnectFromPeripheral(notification : NSNotification) {
        updateConnectionStatusFromNotification(notification)
    }
    
    
    private func updateConnectionStatusFromNotification(notification: NSNotification) {
        guard let peripheralUuid = notification.userInfo?["uuid"] as? String else {
            return
        }
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            if let index = self.peripheralList.indexOfPeripheralIdentifier(peripheralUuid) {
                self.baseTableView.reloadDataForRowIndexes(NSIndexSet(index: index), columnIndexes: NSIndexSet(index: 0))
                
                if index == self.baseTableView.selectedRow {
                    self.detailsViewController.updateDetailsUI()
                }
            }
            })
    }
    
    // MARK - Actions
    @IBAction func onClickRefresh(sender: AnyObject) {
        BleManager2.sharedInstance.refreshPeripherals()
    }
    
    private func onClickConnectionAction(blePeripheral: BlePeripheral2) {
        let bleManager = BleManager2.sharedInstance
        
        switch blePeripheral.state {
        case .Connected:
            bleManager.disconnect(blePeripheral)
        case .Disconnected:
            bleManager.connect(blePeripheral)
        default:
            break
        }
    }
    
    func selectRowForPeripheralIdentifier(identifier: String?) {
        var found = false
        
        peripheralList.resetUserSelectionTime()
        
        if let index = peripheralList.indexOfPeripheralIdentifier(identifier) {
            baseTableView.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: false)
            detailsViewController.updateDetailsUI()
            found = true
        }
        
        if (!found) {
            baseTableView.deselectAll(nil)
        }
    }
    
    // MARK: - Localization
    private func connectionLocalizedString(state: CBPeripheralState) -> String {
        var stringId: String
        
        switch state {
        case .Connected:
            stringId = "peripherallist_disconnect"
        case .Connecting:
            stringId = "peripherallist_connecting"
        case .Disconnected:
            stringId = "peripherallist_connect"
        }
        
        return LocalizationManager.sharedInstance.localizedString(stringId)
    }
}

// MARK: - NSTableViewDataSource
extension PeripheralListViewController: NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return peripheralList.blePeripheralsCount
    }
}

// MARK: NSTableViewDelegate
extension PeripheralListViewController: NSTableViewDelegate {
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cell = tableView.makeViewWithIdentifier("PeripheralCell", owner: self) as! PeripheralTableCellView
        
        let selectedBlePeripheralIdentifier = peripheralList.blePeripherals[row];
        let blePeripheral = BleManager2.sharedInstance.blePeripheralWithUuid(selectedBlePeripheralIdentifier)!
        let name = blePeripheral.name != nil ? blePeripheral.name! : LocalizationManager.sharedInstance.localizedString("peripherallist_unnamed")
        cell.titleTextField.stringValue = name
        
        let isUartCapable = blePeripheral.isUartAdvertised()
        cell.subtitleTextField.stringValue = LocalizationManager.sharedInstance.localizedString(isUartCapable ? "peripherallist_uartavailable" : "peripherallist_uartunavailable")
        cell.rssiImageView.image = signalImageForRssi(blePeripheral.rssi)

        cell.connectButton.title = connectionLocalizedString(blePeripheral.state)
        cell.connectButton.enabled = blePeripheral.state == .Connected || blePeripheral.state == .Disconnected
        
        cell.onClickConnectAction = {
            self.onClickConnectionAction(blePeripheral)
        }
        
        return cell;
    }
    
    func tableViewSelectionIsChanging(notification: NSNotification) {   // Note: used tableViewSelectionIsChanging instead of tableViewSelectionDidChange because if a didDiscoverPeripheral notification arrives when the user is changing the row but before the user releases the mouse button, then it would be cancelled (and the user would notice that something weird happened)
        
        peripheralSelectedChanged()
    }

    func tableViewSelectionDidChange(notification: NSNotification) {
        peripheralSelectedChanged()
    }

    func peripheralSelectedChanged() {
        //peripheralList.selectRow(baseTableView.selectedRow)
        let row = baseTableView.selectedRow
        let peripheralUuid: String? = row >= 0 ? peripheralList.blePeripherals[row]:nil
        selectRowForPeripheralIdentifier(peripheralUuid)
    }
}
