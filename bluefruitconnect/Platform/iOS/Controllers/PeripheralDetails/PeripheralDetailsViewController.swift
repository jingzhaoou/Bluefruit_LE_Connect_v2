//
//  PeripheralDetailsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PeripheralDetailsViewController: ScrollingTabBarViewController {
    
    var selectedBlePeripheral : BlePeripheral?
    fileprivate var isObservingBle = false

    fileprivate var emptyViewController : EmptyDetailsViewController!
    
    fileprivate let firmwareUpdater = FirmwareUpdater()
    fileprivate var dfuTabIndex = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let splitViewController = self.splitViewController {
            navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            navigationItem.leftItemsSupplementBackButton = true
        }

        emptyViewController = storyboard!.instantiateViewController(withIdentifier: "EmptyDetailsViewController") as! EmptyDetailsViewController
        
        if selectedBlePeripheral != nil {
            didConnectToPeripheral()
        }
        else {
            
            let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
            if !isFullScreen {
                showEmpty(true)
                self.emptyViewController.setConnecting(false)
            }
        }
        
        
        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
        guard !isFullScreen || selectedBlePeripheral != nil else {
            DLog("detail: peripheral disconnected by viewWillAppear. Abort")
            return
        }
        
        // Subscribe to Ble Notifications
        let notificationCenter = NotificationCenter.default
        if !isFullScreen {       // For compact mode, the connection is managed by the peripheral list
            notificationCenter.addObserver(self, selector: #selector(willConnectToPeripheral(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillConnectToPeripheral.rawValue), object: nil)
            notificationCenter.addObserver(self, selector: #selector(didConnectToPeripheral(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidConnectToPeripheral.rawValue), object: nil)
        }
        notificationCenter.addObserver(self, selector: #selector(willDisconnectFromPeripheral(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue), object: nil)
        notificationCenter.addObserver(self, selector: #selector(didDisconnectFromPeripheral(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue), object: nil)
        isObservingBle = true

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
           }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        
    }
    
    deinit {
        // Remove notifications. Note: don't do this on viewwilldissapear because connection should still work when a new viewcontroller is pushed. i.e.: ControlPad)
        if isObservingBle {
            let notificationCenter = NotificationCenter.default
            let isFullScreen =  UIScreen.main.traitCollection.horizontalSizeClass == .compact
            if !isFullScreen {
                notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillConnectToPeripheral.rawValue), object: nil)
                notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidConnectToPeripheral.rawValue), object: nil)
            }
            notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue), object: nil)
            notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue), object: nil)
            isObservingBle = false
        }
    }
    
    func willConnectToPeripheral(_ notification: Notification) {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.showEmpty(true)
            self.emptyViewController.setConnecting(true)
            })
    }

    func didConnectToPeripheral(_ notification: Notification) {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.didConnectToPeripheral()
            })
    }
    
    func didConnectToPeripheral() {
        guard BleManager.sharedInstance.blePeripheralConnected != nil else {
            DLog("Warning: didConnectToPeripheral with empty blePeripheralConnected");
            return
        }
        
        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected!
        blePeripheral.peripheral.delegate = self
        
        // UI
        self.showEmpty(false)
        
        startUpdatesCheck()
        //setupConnectedPeripheral()
    }
    
    fileprivate func setupConnectedPeripheral() {
        // UI: Add Info tab
        let infoViewController = self.storyboard!.instantiateViewController(withIdentifier: "InfoModuleViewController") as! InfoModuleViewController
        
        
        infoViewController.onServicesDiscovered = { [weak self] in
            // optimization: wait till info discover services to continue, instead of discovering services by myself
            self?.servicesDiscovered()
        }
        
        let localizationManager = LocalizationManager.sharedInstance
        infoViewController.tabBarItem.title = localizationManager.localizedString("info_tab_title")      // Tab title
        infoViewController.tabBarItem.image = UIImage(named: "tab_info_icon")

        setViewControllers([infoViewController], animated: false)
        selectedIndex = 0
    }
    
    func willDisconnectFromPeripheral(_ notification : Notification) {
        DLog("detail: peripheral willDisconnect")
        DispatchQueue.main.async(execute: { [unowned self] in
            let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
            if isFullScreen {       // executed when bluetooth is stopped
                // Back to peripheral list
                if let parentNavigationController = (self.navigationController?.parent as? UINavigationController) {
                    parentNavigationController.popToRootViewController(animated: true)
                }
            }
            else {
                self.showEmpty(true)
                self.emptyViewController.setConnecting(false)
            }
            //self.cancelRssiTimer()
            })
        
        let blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        blePeripheral?.peripheral.delegate = nil
    }
    
    func didDisconnectFromPeripheral(_ notification : Notification) {
        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
        
        DispatchQueue.main.async(execute: { [unowned self] in
            DLog("detail: disconnection")
            
            if !isFullScreen {
                DLog("detail: show empty")
                self.navigationController?.popToRootViewController(animated: false)       // pop any viewcontrollers (like ControlPad)
                self.showEmpty(true)
                self.emptyViewController.setConnecting(false)
            }
            
            // Show disconnected alert (if no previous alert is shown)
            if self.presentedViewController == nil {
                let localizationManager = LocalizationManager.sharedInstance
                let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("peripherallist_peripheraldisconnected"), preferredStyle: .alert)
                let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler: { (_) -> Void in
                    let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
                    
                    if isFullScreen {
                        self.goBackToPeripheralList()
                    }
                })
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
            }
            else {
                DLog("disconnection detected but cannot go to periperalList because there is a presentedViewController on screen")
            }
            
            })
    }

    fileprivate func goBackToPeripheralList() {
        // Back to peripheral list
        if let parentNavigationController = (self.navigationController?.parent as? UINavigationController) {
            parentNavigationController.popToRootViewController(animated: true)
        }

    }
    
    func showEmpty(_ showEmpty : Bool) {
        
        hideTabBar(showEmpty)
        if showEmpty {
            // Show empty view (if needed)
            if viewControllers?.count != 1 || viewControllers?.first != emptyViewController {
                viewControllers = [emptyViewController]
            }
            
            emptyViewController.startAnimating()
        }
        else {
            emptyViewController.stopAnimating()
        }
    }
    
    func servicesDiscovered() {
        
        DLog("PeripheralDetailsViewController servicesDiscovered")
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            
            if let services = blePeripheral.peripheral.services {
                DispatchQueue.main.async(execute: { [unowned self] in
                    
                    let localizationManager = LocalizationManager.sharedInstance
                    
                    // Uart Modules
                    let hasUart = blePeripheral.hasUart()
                    var viewControllersToAppend: [UIViewController] = []
                    if (hasUart) {
                        // Uart Tab
                        if Config.isUartModuleEnabled {
                            let uartViewController = self.storyboard!.instantiateViewController(withIdentifier: "UartModuleViewController") as! UartModuleViewController
                            uartViewController.tabBarItem.title = localizationManager.localizedString("uart_tab_title")      // Tab title
                            uartViewController.tabBarItem.image = UIImage(named: "tab_uart_icon")
                            
                            viewControllersToAppend.append(uartViewController)
                        }
                        
                        // PinIO
                        if Config.isPinIOModuleEnabled {
                            let pinioViewController = self.storyboard!.instantiateViewController(withIdentifier: "PinIOModuleViewController") as! PinIOModuleViewController
                            
                            pinioViewController.tabBarItem.title = localizationManager.localizedString("pinio_tab_title")      // Tab title
                            pinioViewController.tabBarItem.image = UIImage(named: "tab_pinio_icon")
                            
                            viewControllersToAppend.append(pinioViewController)
                        }
                        
                        // Controller Tab
                        if Config.isControllerModuleEnabled {
                            let controllerViewController = self.storyboard!.instantiateViewController(withIdentifier: "ControllerModuleViewController") as! ControllerModuleViewController
                            
                            controllerViewController.tabBarItem.title = localizationManager.localizedString("controller_tab_title")      // Tab title
                            controllerViewController.tabBarItem.image = UIImage(named: "tab_controller_icon")
                            
                            viewControllersToAppend.append(controllerViewController)
                        }
                    }
                    
                    // DFU Tab
                    let kNordicDeviceFirmwareUpdateService = "00001530-1212-EFDE-1523-785FEABCD123"    // DFU service UUID
                    let hasDFU = services.contains(where: { (service : CBService) -> Bool in
                        service.uuid.isEqual(CBUUID(string: kNordicDeviceFirmwareUpdateService))
                    })
                    
                    if Config.isNeoPixelModuleEnabled && hasUart && hasDFU {        // Neopixel is not available on old boards (those without DFU)
                        // Neopixel Tab
                        let neopixelsViewController = self.storyboard!.instantiateViewController(withIdentifier: "NeopixelModuleViewController") as! NeopixelModuleViewController
                        
                        neopixelsViewController.tabBarItem.title = localizationManager.localizedString("neopixels_tab_title")      // Tab title
                        neopixelsViewController.tabBarItem.image = UIImage(named: "tab_neopixel_icon")
                        
                        viewControllersToAppend.append(neopixelsViewController)
                    }
                    
                    if (hasDFU) {
                        if Config.isDfuModuleEnabled {
                            let dfuViewController = self.storyboard!.instantiateViewController(withIdentifier: "DfuModuleViewController") as! DfuModuleViewController
                            dfuViewController.tabBarItem.title = localizationManager.localizedString("dfu_tab_title")      // Tab title
                            dfuViewController.tabBarItem.image = UIImage(named: "tab_dfu_icon")
                            viewControllersToAppend.append(dfuViewController)
                            self.dfuTabIndex = viewControllersToAppend.count         // don't -1 because index is always present and adds 1 to the index
                        }
                    }
                    
                    // Add tabs
                    if self.viewControllers != nil {
                        let numViewControllers = self.viewControllers!.count
                        if  numViewControllers > 1 {      // if we already have viewcontrollers, remove all except info (to avoud duplicates)
                            self.viewControllers!.removeSubrange(Range(1..<numViewControllers))
                        }
                        
                        // Append viewcontrollers (do it here all together to avoid deleting/creating addchilviewcontrollers)
                        if viewControllersToAppend.count > 0 {
                            self.viewControllers!.append(contentsOf: viewControllersToAppend)
                        }
                    }
                    
                    })
                
                
            }
        }
    }

    fileprivate func startUpdatesCheck() {
        
        // Refresh updates available
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected  {
            let releases = FirmwareUpdater.releases(withBetaVersions: Preferences.showBetaVersions)
            firmwareUpdater.checkUpdates(for: blePeripheral.peripheral, delegate: self, shouldDiscoverServices: true, releases: releases, shouldRecommendBetaReleases: false)
        }
    }

    
    func updateRssiUI() {
        /*
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            let rssi = blePeripheral.rssi
            //DLog("rssi: \(rssi)")
            infoRssiLabel.stringValue = String.format(LocalizationManager.sharedInstance.localizedString("peripheraldetails_rssi_format"), rssi) // "\(rssi) dBm"
            infoRssiImageView.image = signalImageForRssi(rssi)
        }
*/
    }
    
    fileprivate func showUpdateAvailableForRelease(_ latestRelease: FirmwareInfo!) {
        let alert = UIAlertController(title:"Update available", message: "Software version \(latestRelease.version) is available", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Go to updates", style: UIAlertActionStyle.default, handler: { [unowned self] _ in
            self.selectedIndex = self.dfuTabIndex
        }))
        alert.addAction(UIAlertAction(title: "Ask later", style: UIAlertActionStyle.default, handler: {  _ in
        }))
        alert.addAction(UIAlertAction(title: "Ignore", style: UIAlertActionStyle.cancel, handler: {  _ in
            Preferences.softwareUpdateIgnoredVersion = latestRelease.version
        }))
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: - CBPeripheralDelegate
extension PeripheralDetailsViewController: CBPeripheralDelegate {
    
    // Send peripheral delegate methods to tab active (each tab will handle these methods)
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        
        if let viewControllers = viewControllers {
            for tabViewController in viewControllers {
                (tabViewController as? CBPeripheralDelegate)?.peripheralDidUpdateName?(peripheral)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        if let viewControllers = viewControllers {
            for tabViewController in viewControllers {
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didModifyServices: invalidatedServices)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let viewControllers = viewControllers {
            for var tabViewController in viewControllers {
                if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                    tabViewController = childViewController
                }
                
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverServices: error)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let viewControllers = viewControllers {
            for var tabViewController in viewControllers {
                if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                    tabViewController = childViewController
                }
                
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverCharacteristicsFor: service, error: error)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if let viewControllers = viewControllers {
            for var tabViewController in viewControllers {
                if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                    tabViewController = childViewController
                }
                
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didDiscoverDescriptorsFor: characteristic, error: error)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        if let viewControllers = viewControllers {
            for var tabViewController in viewControllers {
                if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                    tabViewController = childViewController
                }
                
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueFor: characteristic, error: error)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {

        
        if let viewControllers = viewControllers {
            for var tabViewController in viewControllers {
                if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                    tabViewController = childViewController
                }
                
                (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didUpdateValueFor: descriptor, error: error)
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        
        // Update peripheral rssi
        let identifierString = peripheral.identifier.uuidString
        if let existingPeripheral = BleManager.sharedInstance.blePeripherals()[identifierString] {
            existingPeripheral.rssi = RSSI.intValue
            //            DLog("received rssi for \(existingPeripheral.name): \(rssi)")
            
            // Update UI
            DispatchQueue.main.async(execute: { [unowned self] in
                self.updateRssiUI()
                })
            
            if let viewControllers = viewControllers {
                for var tabViewController in viewControllers {
                    if let childViewController = (tabViewController as? UINavigationController)?.viewControllers.last {
                        tabViewController = childViewController
                    }
                    
                    (tabViewController as? CBPeripheralDelegate)?.peripheral?(peripheral, didReadRSSI: RSSI, error: error)
                }
            }
        }
    }
    
}

// MARK: - FirmwareUpdaterDelegate
extension PeripheralDetailsViewController: FirmwareUpdaterDelegate {
    func onFirmwareUpdatesAvailable(_ isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData?, allReleases: [AnyHashable: Any]?) {
        DLog("FirmwareUpdaterDelegate isUpdateAvailable: \(isUpdateAvailable)")
        
        DispatchQueue.main.async(execute: { [weak self] in
            
            if let context = self {

                context.setupConnectedPeripheral()
                if isUpdateAvailable {
                    context.showUpdateAvailableForRelease(latestRelease)
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
