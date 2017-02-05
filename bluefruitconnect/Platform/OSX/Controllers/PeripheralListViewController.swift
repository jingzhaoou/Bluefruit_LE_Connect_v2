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
    // Config
    static let kFiltersPanelClosedHeight: CGFloat = 55
    static let kFiltersPanelOpenHeight: CGFloat = 170

    // UI
    @IBOutlet weak var baseTableView: NSTableView!
    @IBOutlet weak var filtersPanelView: NSView!
    @IBOutlet weak var filtersBackgroundView: NSView!
    @IBOutlet weak var filtersPanelViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var filterTitleTextField: NSTextField!
    @IBOutlet weak var filtersDisclosureButton: NSButton!
    @IBOutlet weak var filtersNameSearchField: NSSearchField!
    @IBOutlet weak var filterRssiValueLabel: NSTextField!
    @IBOutlet weak var filtersRssiSlider: NSSlider!
    @IBOutlet weak var filtersShowUnnamed: NSButton!
    @IBOutlet weak var filtersOnlyWithUartButton: NSButton!
    @IBOutlet weak var filtersClearButton: NSButton!

    // Data
    fileprivate var peripheralList: PeripheralList! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register default preferences
        //Preferences.resetDefaults()       // Debug Reset
        Preferences.registerDefaults()

        peripheralList = PeripheralList()                  // Initialize here to wait for Preferences.registerDefaults to be executed
        
        // Setup StatusManager
        StatusManager.sharedInstance.peripheralListViewController = self
        
        // Subscribe to Ble Notifications
        NotificationCenter.default.addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didDisconnectFromPeripheral(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue), object: nil)
        
        // Appearance
        filtersBackgroundView.wantsLayer = true
        filtersBackgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue), object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()

        // Filters
        openFiltersPanel(Preferences.scanFilterIsPanelOpen, animated: false)
        updateFiltersTitle()
        filtersNameSearchField.stringValue = peripheralList.filterName ?? ""
        setRssiSliderValue(peripheralList.rssiFilterValue)
        filtersShowUnnamed.state = peripheralList.isUnnamedEnabled ? NSOnState:NSOffState
        filtersOnlyWithUartButton.state = peripheralList.isOnlyUartEnabled ? NSOnState:NSOffState
    }
    

    func didDiscoverPeripheral(_ notification : Notification) {
        DispatchQueue.main.async(execute: {[unowned self] in

            // Reload data
            self.baseTableView.reloadData()
            
            // Select identifier if still available
            if let selectedPeripheralRow = self.peripheralList.selectedPeripheralRow {
                self.baseTableView.selectRowIndexes(IndexSet(integer: selectedPeripheralRow), byExtendingSelection: false)
            }
        })
    }

    func didDisconnectFromPeripheral(_ notification : Notification) {
        DispatchQueue.main.async(execute: {[unowned self] in
            
            if (BleManager.sharedInstance.blePeripheralConnected == nil && self.baseTableView.selectedRow >= 0) {
                
                // Unexpected disconnect if the row is still selected but the connected peripheral is nil and the time since the user selected a new peripheral is bigger than kMinTimeSinceUserSelection seconds
                let kMinTimeSinceUserSelection = 1.0    // in secs
                if self.peripheralList.elapsedTimeSinceSelection > kMinTimeSinceUserSelection {
                    self.baseTableView.deselectAll(nil)
                    
                    let localizationManager = LocalizationManager.sharedInstance
                    let alert = NSAlert()
                    alert.messageText = localizationManager.localizedString("peripherallist_peripheraldisconnected")
                    alert.addButton(withTitle: localizationManager.localizedString("dialog_ok"))
                    alert.alertStyle = .warning
                    alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
                }
            }
            })
    }
    
    // MARK: -
    func selectRowForPeripheralIdentifier(_ identifier : String?) {
        var found = false
        
        if let index = peripheralList.indexOfPeripheralIdentifier(identifier) {
            baseTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            found = true
        }
        
        if (!found) {
            baseTableView.deselectAll(nil)
        }
    }
    
    // MARK: - Filters
    fileprivate func openFiltersPanel(_ isOpen: Bool, animated: Bool) {
        
        Preferences.scanFilterIsPanelOpen = isOpen
        self.filtersDisclosureButton.state = isOpen ? NSOnState:NSOffState
        
        NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
            
            context.duration = animated ? 0.3:0
            self.filtersPanelViewHeightConstraint.animator().constant = isOpen ? PeripheralListViewController.kFiltersPanelOpenHeight:PeripheralListViewController.kFiltersPanelClosedHeight
            
            }, completionHandler: nil)
    }

    fileprivate func updateFiltersTitle() {
        let filtersTitle = peripheralList.filtersDescription()
        filterTitleTextField.stringValue = filtersTitle != nil ? "Filter: \(filtersTitle!)" : "No filter selected"
        
        filtersClearButton.isHidden = !peripheralList.isAnyFilterEnabled()
    }
    
    func onFilterNameSettingsNameContains(_ sender: NSMenuItem) {
        peripheralList.isFilterNameExact = false
        updateFilters()
    }
    
    func onFilterNameSettingsNameEquals(_ sender: NSMenuItem) {
        peripheralList.isFilterNameExact = true
        updateFilters()
    }
    
    func onFilterNameSettingsMatchCase(_ sender: NSMenuItem) {
        peripheralList.isFilterNameCaseInsensitive = false
        updateFilters()
    }
    
    func onFilterNameSettingsIgnoreCase(_ sender: NSMenuItem) {
        peripheralList.isFilterNameCaseInsensitive = true
        updateFilters()
    }
    
    fileprivate func updateFilters() {
        updateFiltersTitle()
        baseTableView.reloadData()
    }
    
    fileprivate func setRssiSliderValue(_ value: Int?) {
        filtersRssiSlider.integerValue = value != nil ? -value! : 100
    }
    
    fileprivate func updateRssiValueLabel() {
        filterRssiValueLabel.stringValue = "\(-filtersRssiSlider.integerValue) dBM"
    }
    
    
    // MARK: - Advertising Packet
    fileprivate func showAdverisingPacketData(_ blePeripheral: BlePeripheral) {
        let localizationManager = LocalizationManager.sharedInstance
        var advertisementString = ""

        for (key, value) in blePeripheral.advertisementData {
            switch key {
            case CBAdvertisementDataLocalNameKey:
                let name = value as! String
                advertisementString += "Local name: \(name)\n"
                
            case CBAdvertisementDataManufacturerDataKey:
                let manufacturerData = value as! Data
                let manufacturerHexString =  hexString(manufacturerData)
                advertisementString += "Manufacturer: \(manufacturerHexString)\n"
                
            case CBAdvertisementDataServiceUUIDsKey:
                let serviceUuids = value as! [CBUUID]
                advertisementString += "Services UUIDs:\n"
                for (cbuuid) in serviceUuids {
                    advertisementString += "\t\(cbuuid.uuidString)\n"
                }
                
            case CBAdvertisementDataServiceDataKey:
                let serviceData = value as! [CBUUID: Data]
                advertisementString += "Services Data:\n"
                for (cbuuid, data) in serviceData {
                    advertisementString += "\tUUID: \(cbuuid.uuidString) Data: \(hexString(data))\n"
                }
                
            case CBAdvertisementDataOverflowServiceUUIDsKey:
                let serviceUuids = value as! [CBUUID]
                advertisementString += "Overflow services:\n"
                for (cbuuid) in serviceUuids {
                    advertisementString += "\t\(cbuuid.uuidString)\n"
                }
            case CBAdvertisementDataTxPowerLevelKey:
                let txPower = value as! NSNumber
                advertisementString += "TX Power Level: \(txPower.intValue)\n"
                
            case CBAdvertisementDataIsConnectable:
                let isConnectable = value as! Bool
                advertisementString += "Connectable: \(isConnectable ? "true":"false")\n"
                
            case CBAdvertisementDataSolicitedServiceUUIDsKey:
                let serviceUuids = value as! [CBUUID]
                advertisementString += "Solicited Service: \(value)\n"
                for (cbuuid) in serviceUuids {
                    advertisementString += "\t\(cbuuid.uuidString)\n"
                }
                
            default:
                DLog("unknown advertising key: \(key)")
            }
        }
        
        let alert = NSAlert()
        alert.messageText = "Advertising packet data"
        alert.informativeText = advertisementString
        alert.addButton(withTitle: localizationManager.localizedString("dialog_ok"))
        alert.alertStyle = .warning
        alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
    
    // MARK: - Actions
    @IBAction func onClickRefresh(_ sender: AnyObject) {
        BleManager.sharedInstance.refreshPeripherals()
    }
    
    @IBAction func onClickFilters(_ sender: AnyObject) {
        openFiltersPanel(!Preferences.scanFilterIsPanelOpen, animated: true)
    }
    
    
    @IBAction func onEditFilterName(_ sender: AnyObject) {
        let isEmpty = (sender.stringValue as String).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
        peripheralList.filterName = isEmpty ? nil:sender.stringValue
        updateFilters()
    }
   
    @IBAction func onClickFilterNameSettings(_ sender: AnyObject) {
        filtersNameSearchField.window?.makeFirstResponder(filtersNameSearchField)           // Force first responder to the text field, so the menu is not grayed down if the text field was not previously selected
        
        let menu = NSMenu(title: "Settings")
        
        menu.addItem(withTitle: "Name contains", action: #selector(onFilterNameSettingsNameContains(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Name equals", action: #selector(onFilterNameSettingsNameEquals(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Matching case", action: #selector(onFilterNameSettingsMatchCase(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Ignoring case", action: #selector(onFilterNameSettingsIgnoreCase(_:)), keyEquivalent: "")
        //NSMenu.popUpContextMenu(menu, withEvent: NSEvent(), forView: view)
        
        let selectedOption0 = peripheralList.isFilterNameExact ? 1:0
        menu.item(at: selectedOption0)!.offStateImage = NSImage(named: "NSMenuOnStateTemplate")
        let selectedOption1 = peripheralList.isFilterNameCaseInsensitive ? 4:3
        menu.item(at: selectedOption1)!.offStateImage = NSImage(named: "NSMenuOnStateTemplate")
        
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation(), in: nil)
    }
    
    
    @IBAction func onFilterRssiChanged(_ sender: NSSlider) {
        let rssiValue = -sender.integerValue
        peripheralList.rssiFilterValue = rssiValue
        updateRssiValueLabel()
        updateFilters()
    }
    
    @IBAction func onFilterOnlyUartChanged(_ sender: NSButton) {
        peripheralList.isOnlyUartEnabled = sender.state == NSOnState
        updateFilters()
    }
    
    @IBAction func onFilterUnnamedChanged(_ sender: AnyObject) {
        peripheralList.isUnnamedEnabled = sender.state == NSOnState
        updateFilters()
    }
    
    @IBAction func onClickRemoveFilters(_ sender: AnyObject) {
        peripheralList.setDefaultFilters()
        filtersNameSearchField.stringValue = peripheralList.filterName ?? ""
        setRssiSliderValue(peripheralList.rssiFilterValue)
        filtersShowUnnamed.state = peripheralList.isUnnamedEnabled ? NSOnState:NSOffState
        filtersOnlyWithUartButton.state = peripheralList.isOnlyUartEnabled ? NSOnState:NSOffState
        updateFilters()
    }
}

// MARK: - NSTableViewDataSource
extension PeripheralListViewController : NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return peripheralList.filteredPeripherals(true).count
    }
}

// MARK: NSTableViewDelegate
extension PeripheralListViewController : NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let cell = tableView.make(withIdentifier: "PeripheralCell", owner: self) as! PeripheralTableCellView
        
        let bleManager = BleManager.sharedInstance
        let blePeripheralsFound = bleManager.blePeripherals()
        let filteredPeripherals = peripheralList.filteredPeripherals(false)
        
        if row < filteredPeripherals.count {        // Check to avoid race conditions
            let localizationManager = LocalizationManager.sharedInstance
            let selectedBlePeripheralIdentifier = filteredPeripherals[row]
            let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
            let name = blePeripheral.name != nil ? blePeripheral.name! : localizationManager.localizedString("peripherallist_unnamed")
            cell.titleTextField.stringValue = name
            
            let isUartCapable = blePeripheral.isUartAdvertised()
            cell.hasUartView.isHidden = !isUartCapable
            cell.subtitleTextField.stringValue = ""
            //cell.subtitleTextField.stringValue = localizationManager.localizedString(isUartCapable ? "peripherallist_uartavailable" : "peripherallist_uartunavailable")
            cell.rssiImageView.image = signalImageForRssi(blePeripheral.rssi)
            
            cell.onDisconnect = {
                tableView.deselectAll(nil)
            }
            
            cell.onClickAdvertising = { [unowned self] in
                self.showAdverisingPacketData(blePeripheral)
            }
            
            cell.showDisconnectButton(row == peripheralList.selectedPeripheralRow)
        }
        
        return cell;
    }
    
    func tableViewSelectionIsChanging(_ notification: Notification) {   // Note: used tableViewSelectionIsChanging instead of tableViewSelectionDidChange because if a didDiscoverPeripheral notification arrives when the user is changing the row but before the user releases the mouse button, then it would be cancelled (and the user would notice that something weird happened)
        
        peripheralSelectedChanged()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        peripheralSelectedChanged()
    }

    func peripheralSelectedChanged() {
        peripheralList.selectRow(baseTableView.selectedRow)
    }
}
