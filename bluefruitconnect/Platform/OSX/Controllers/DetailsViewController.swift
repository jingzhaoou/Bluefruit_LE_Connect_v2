//
//  DetailsViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 25/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
import CoreBluetooth
import MSWeakTimer

// Protocol that should implement viewControllers used as tabs
protocol DetailTab {
    func tabWillAppear()
    func tabWillDissapear()
    func tabReset()
}

class DetailsViewController: NSViewController {

    // Configuration
    static fileprivate let kNeopixelsEnabled = false
    
    // UI
    @IBOutlet weak var emptyView: NSTabView!
    @IBOutlet weak var emptyLabel: NSTextField!
    
    @IBOutlet weak var modeTabView: NSTabView!

    @IBOutlet weak var infoView: NSView!
    @IBOutlet weak var infoNameLabel: NSTextField!
    @IBOutlet weak var infoRssiImageView: NSImageView!
    @IBOutlet weak var infoRssiLabel: NSTextField!
    @IBOutlet weak var infoUartImageView: NSImageView!
    @IBOutlet weak var infoUartLabel: NSTextField!
    @IBOutlet weak var infoDsiImageView: NSImageView!
    @IBOutlet weak var infoDsiLabel: NSTextField!
    @IBOutlet weak var infoDfuImageView: NSImageView!
    @IBOutlet weak var infoDfuLabel: NSTextField!
    
    // Modules
    fileprivate var pinIOViewController: PinIOViewController?
    fileprivate var updateViewController: FirmwareUpdateViewController?
    
    // Rssi
    fileprivate static let kRssiUpdateInterval = 2.0       // in seconds
    fileprivate var rssiTimer : MSWeakTimer?
    
    // Software upate autocheck
    fileprivate let firmwareUpdater = FirmwareUpdater()

    
    //
    override func viewDidLoad() {
        super.viewDidLoad()
        
        infoView.wantsLayer = true
        infoView.layer?.borderWidth = 1
        infoView.layer?.borderColor = NSColor.lightGray.cgColor
        
        showEmpty(true)
    }
    
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Subscribe to Ble Notifications
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(willConnectToPeripheral(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillConnectToPeripheral.rawValue), object: nil)
        notificationCenter.addObserver(self, selector: #selector(didConnectToPeripheral(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidConnectToPeripheral.rawValue), object: nil)
        notificationCenter.addObserver(self, selector: #selector(willDisconnectFromPeripheral(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue), object: nil)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillConnectToPeripheral.rawValue), object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidConnectToPeripheral.rawValue), object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue), object: nil)
    }
    
    deinit {
        cancelRssiTimer()
    }
    
    func willConnectToPeripheral(_ notification : Notification) {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.showEmpty(true)
            self.emptyLabel.stringValue = LocalizationManager.sharedInstance.localizedString("peripheraldetails_connecting")
            })
    }
    
    func didConnectToPeripheral(_ notification : Notification) {

        guard BleManager.sharedInstance.blePeripheralConnected != nil else {
            DLog("Warning: didConnectToPeripheral with empty blePeripheralConnected");
            return;
        }

        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected!
        blePeripheral.peripheral.delegate = self

        // UI
        DispatchQueue.main.async(execute: { [unowned self] in
            self.showEmpty(false)
            
            for tabViewItem in self.modeTabView.tabViewItems {
                self.modeTabView.removeTabViewItem(tabViewItem)
            }
            
            self.startUpdatesCheck()
        })
    }
    
    fileprivate func startUpdatesCheck() {
        
        // Refresh updates available
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            
            let releases = FirmwareUpdater.releases(withBetaVersions: Preferences.showBetaVersions)
            firmwareUpdater.checkUpdates(for: blePeripheral.peripheral, delegate: self, shouldDiscoverServices: true, releases: releases, shouldRecommendBetaReleases: false)
        }
    }

    fileprivate func setupConnectedPeripheral() {
        guard let blePeripheral = BleManager.sharedInstance.blePeripheralConnected else {
            return
        }
        
        // UI: Info
        let name = blePeripheral.name != nil ? blePeripheral.name! : LocalizationManager.sharedInstance.localizedString("peripherallist_unnamed")
        self.infoNameLabel.stringValue = name
        self.updateRssiUI()
        
        self.cancelRssiTimer()
        let privateQueue = DispatchQueue(label: "private_queue", attributes: DispatchQueue.Attributes.concurrent);
        self.rssiTimer = MSWeakTimer.scheduledTimer(withTimeInterval: DetailsViewController.kRssiUpdateInterval, target: self, selector: #selector(requestUpdateRssi), userInfo: nil, repeats: true, dispatchQueue: privateQueue)
        
        // UI: Add Info tab
        let infoViewController = self.storyboard?.instantiateController(withIdentifier: "InfoViewController") as! InfoViewController
        
        infoViewController.onServicesDiscovered = { [weak self] in
            // optimization: wait till info discover services to continue, instead of discovering services by myself
            self?.servicesDiscovered()
        }
        
        infoViewController.onInfoScanFinished = { [weak self] in
            // tell the pinio that can start querying without problems
            self?.pinIOViewController?.infoFinishedScanning = true
            self?.updateViewController?.infoFinishedScanning = true
        }
        
        
        let infoTabViewItem = NSTabViewItem(viewController: infoViewController)
        self.modeTabView.addTabViewItem(infoTabViewItem)
        infoViewController.tabReset()
        
        self.modeTabView.selectFirstTabViewItem(nil)
    }
    
    func requestUpdateRssi() {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            //DLog("request rssi for \(blePeripheral.name)")
            blePeripheral.peripheral.readRSSI()
        }
    }
    
    func willDisconnectFromPeripheral(_ notification : Notification) {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.showEmpty(true)
            self.cancelRssiTimer()
            
            for tabViewItem in self.modeTabView.tabViewItems {
                self.modeTabView.removeTabViewItem(tabViewItem)
            }
            })
        
        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        blePeripheral?.peripheral.delegate = nil
    }
    
    func cancelRssiTimer() {
        rssiTimer?.invalidate()
        rssiTimer = nil
    }
    
    func showEmpty(_ isEmpty : Bool) {
        infoView.isHidden = isEmpty
        modeTabView.isHidden = isEmpty
        emptyView.isHidden = !isEmpty
        if (isEmpty) {
            emptyLabel.stringValue = LocalizationManager.sharedInstance.localizedString("peripheraldetails_select")
        }
    }
    
    
    func servicesDiscovered() {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            if let services = blePeripheral.peripheral.services {
                
                DispatchQueue.main.async(execute: { [unowned self] in
                    
                    var currentTabIndex = 1     // 0 is Info
                    
                    let hasUart = blePeripheral.hasUart()
                    self.infoUartImageView.image = NSImage(named: hasUart ?"NSStatusAvailable":"NSStatusNone")
                    //infoUartLabel.toolTip = "UART Service \(hasUart ? "" : "not ")available"
                    
                    if (hasUart) {
                        // Uart Tab
                        if Config.isUartModuleEnabled {
                            var uartTabIndex = self.indexForTabWithClass("UartViewController")
                            if uartTabIndex < 0 {
                                // Add Uart tab
                                let uartViewController = self.storyboard?.instantiateController(withIdentifier: "UartViewController") as! UartViewController
                                let uartTabViewItem = NSTabViewItem(viewController: uartViewController)
                                uartTabIndex = currentTabIndex
                                currentTabIndex += 1
                                self.modeTabView.insertTabViewItem(uartTabViewItem, at: uartTabIndex)
                            }
                            
                            let uartViewController = self.modeTabView.tabViewItems[uartTabIndex].viewController as! UartViewController
                            uartViewController.tabReset()
                        }
                        
                        // PinIO
                        if Config.isPinIOModuleEnabled {
                            var pinIOTabIndex = self.indexForTabWithClass("PinIOViewController")
                            if pinIOTabIndex < 0 {
                                // Add PinIO tab
                                self.pinIOViewController = self.storyboard?.instantiateController(withIdentifier: "PinIOViewController") as? PinIOViewController
                                let pinIOTabViewItem = NSTabViewItem(viewController: self.pinIOViewController!)
                                pinIOTabIndex = currentTabIndex
                                currentTabIndex += 1
                                self.modeTabView.insertTabViewItem(pinIOTabViewItem, at: pinIOTabIndex)
                            }

                            let pinIOViewController = self.modeTabView.tabViewItems[pinIOTabIndex].viewController as! PinIOViewController
                            pinIOViewController.tabReset()
                        }
                    }
                    
                    // DFU Tab
                    let kNordicDeviceFirmwareUpdateService = "00001530-1212-EFDE-1523-785FEABCD123"    // DFU service UUID
                    let hasDFU = services.contains(where: { (service : CBService) -> Bool in
                        service.uuid.isEqual(CBUUID(string: kNordicDeviceFirmwareUpdateService))
                    })
                    
                    self.infoDfuImageView.image = NSImage(named: hasDFU ?"NSStatusAvailable":"NSStatusNone")
                    
                    if (hasDFU) {
                        if Config.isDfuModuleEnabled {
                            var dfuTabIndex = self.indexForTabWithClass("FirmwareUpdateViewController")
                            if dfuTabIndex < 0 {
                                // Add Firmware Update tab
                                self.updateViewController = self.storyboard?.instantiateController(withIdentifier: "FirmwareUpdateViewController") as? FirmwareUpdateViewController
                                let updateTabViewItem = NSTabViewItem(viewController: self.updateViewController!)
                                dfuTabIndex = currentTabIndex
                                currentTabIndex += 1
                                self.modeTabView.insertTabViewItem(updateTabViewItem, at: dfuTabIndex)
                            }
                            
                            let updateViewController = (self.modeTabView.tabViewItems[dfuTabIndex].viewController as! FirmwareUpdateViewController)
                            updateViewController.tabReset()
                        }
                        
                    }
                    
                    // DIS Indicator
                    let kDisServiceUUID = "180A"    // DIS service UUID
                    let hasDIS = services.contains(where: { (service : CBService) -> Bool in
                        service.uuid.isEqual(CBUUID(string: kDisServiceUUID))
                    })
                    self.infoDsiImageView.image = NSImage(named: hasDIS ?"NSStatusAvailable":"NSStatusNone")
                    
                    
                    // Neopixel Tab
                    if (hasUart && Config.isNeoPixelModuleEnabled) {
                        
                        var neopixelTabIndex = self.indexForTabWithClass("NeopixelViewControllerOSX")
                        if neopixelTabIndex < 0 {
                            // Add Neopixel tab
                            let neopixelViewController = self.storyboard?.instantiateController(withIdentifier: "NeopixelViewControllerOSX") as! NeopixelViewControllerOSX
                            let neopixelTabViewItem = NSTabViewItem(viewController: neopixelViewController)
                            neopixelTabIndex = currentTabIndex
                            currentTabIndex += 1
                            self.modeTabView.insertTabViewItem(neopixelTabViewItem, at: neopixelTabIndex)
                        }
                        
                        let neopixelViewController = self.modeTabView.tabViewItems[neopixelTabIndex].viewController as! NeopixelViewControllerOSX
                        neopixelViewController.tabReset()
                        
                    }
                    
                    })
            }
        }
    }
    
    fileprivate func indexForTabWithClass(_ tabClassName : String) -> Int {
        var index = -1
        for i in 0..<modeTabView.tabViewItems.count {
            let className = String(describing: type(of: modeTabView.tabViewItems[i].viewController!))
            if className == tabClassName {
                index = i
                break
            }
        }
        
        return index
    }
    
    func updateRssiUI() {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            let rssi = blePeripheral.rssi
            //DLog("rssi: \(rssi)")
            infoRssiLabel.stringValue = String(format:LocalizationManager.sharedInstance.localizedString("peripheraldetails_rssi_format"), arguments:[rssi]) // "\(rssi) dBm"
            infoRssiImageView.image = signalImageForRssi(rssi)
        }
    }
    
    fileprivate func showUpdateAvailableForRelease(_ latestRelease: FirmwareInfo!) {
        if let window = self.view.window {
            let alert = NSAlert()
            alert.messageText = "Update available"
            alert.informativeText = "Software version \(latestRelease.version) is available"
            alert.addButton(withTitle: "Go to updates")
            alert.addButton(withTitle: "Ask later")
            alert.addButton(withTitle: "Ignore")
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window, completionHandler: { modalResponse in
                if modalResponse == NSAlertFirstButtonReturn {
                    self.modeTabView.selectLastTabViewItem(nil)
                }
                else if modalResponse == NSAlertThirdButtonReturn {
                     Preferences.softwareUpdateIgnoredVersion = latestRelease.version
                }
            })
        }
        else {
            DLog("onUpdateDialogSuccess: window not defined")
        }        
        
    }

}

// MARK: - CBPeripheralDelegate
extension DetailsViewController : CBPeripheralDelegate {
    
    // Send peripheral delegate methods to tab active (each tab will handle these methods)
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheralDidUpdateName?(peripheral)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        // Services needs to be discovered again
        pinIOViewController?.infoFinishedScanning = false
        updateViewController?.infoFinishedScanning = false
        
        //
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didModifyServices: invalidatedServices)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverServices: error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverCharacteristicsFor: service, error: error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverDescriptorsFor: characteristic, error: error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueFor: characteristic, error: error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
 
        for tabViewItem in modeTabView.tabViewItems {
            (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueFor: descriptor, error: error)
        }
    }
    
    func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {

        // Update peripheral rssi
        let identifierString = peripheral.identifier.uuidString
        if let existingPeripheral = BleManager.sharedInstance.blePeripherals()[identifierString], let rssi =  peripheral.rssi?.intValue {
            existingPeripheral.rssi = rssi
//            DLog("received rssi for \(existingPeripheral.name): \(rssi)")
            
            // Update UI
            DispatchQueue.main.async(execute: { [unowned self] in
                self.updateRssiUI()
                })
            
            for tabViewItem in modeTabView.tabViewItems {
                (tabViewItem.viewController as? CBPeripheralDelegate)?.peripheralDidUpdateRSSI?(peripheral, error: error)
            }
        }
    }
}

// MARK: - NSTabViewDelegate
extension DetailsViewController: NSTabViewDelegate {
    
    func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        
        if modeTabView.selectedTabViewItem != tabViewItem {
            if let detailTabViewController = modeTabView.selectedTabViewItem?.viewController as? DetailTab {     // Note: all tab viewcontrollers should conform to protocol
                detailTabViewController.tabWillDissapear()
            }
        }
    }
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard BleManager.sharedInstance.blePeripheralConnected != nil else {
            DLog("didSelectTabViewItem while disconnecting")
            return
        }
        
        let detailTabViewController = tabViewItem?.viewController as! DetailTab     // Note: all tab viewcontrollers should conform to protocol DetailTab
        detailTabViewController.tabWillAppear()
    }
    
    /*
    func tabView(tabView: NSTabView, shouldSelectTabViewItem tabViewItem: NSTabViewItem?) -> Bool {
        if tabViewItem?.viewController is PinIOViewController {
            return false
        }
        else {
            return true
        }
    }
*/
}

// MARK: - FirmwareUpdaterDelegate
extension DetailsViewController: FirmwareUpdaterDelegate {
    func onFirmwareUpdatesAvailable(_ isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData?, allReleases: [AnyHashable: Any]?) {
        DLog("FirmwareUpdaterDelegate isUpdateAvailable: \(isUpdateAvailable)")
        
        DispatchQueue.main.async(execute: { [weak self] in
            
            if let context = self {
                
                context.setupConnectedPeripheral()
                if isUpdateAvailable {
                    self?.showUpdateAvailableForRelease(latestRelease)
                }
            }
            })
    }
    
    func onDfuServiceNotFound() {
        DLog("FirmwareUpdaterDelegate: onDfuServiceNotFound")
        
        DispatchQueue.main.async(execute: { [weak self] in
            self?.setupConnectedPeripheral()
            })
    }
    
    fileprivate func onUpdateDialogError(_ errorMessage:String, exitOnDismiss: Bool = false) {
        DLog("FirmwareUpdaterDelegate: onUpdateDialogError")
    }
}

