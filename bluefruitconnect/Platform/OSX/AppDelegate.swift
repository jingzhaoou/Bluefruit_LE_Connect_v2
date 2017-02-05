//
//  AppDelegate.swift
//  bluefruitconnect
//
//  Created by Antonio García on 22/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    // UI
    @IBOutlet weak var peripheralsMenu: NSMenu!
    @IBOutlet weak var startScanningMenuItem: NSMenuItem!
    @IBOutlet weak var stopScanningMenuItem: NSMenuItem!
    
    // Status Menu
    let statusMenu = NSMenu();
    var isMenuOpen = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Init
        peripheralsMenu.delegate = self
        peripheralsMenu.autoenablesItems = false


        // Check if there is any update to the fimware database
        FirmwareUpdater.refreshSoftwareUpdatesDatabase(from: Preferences.updateServerUrl as URL!, completionHandler: nil)

        // Add system status button
        setupStatusButton()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        
        releaseStatusButton()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        /*
        let appInSystemStatusBar = Preferences.appInSystemStatusBar
        return appInSystemStatusBar ? false : true
*/
        return true
    }
    
    // MARK: System status button
    func setupStatusButton() {

        statusItem.image = NSImage(named: "sytemstatusicon")
        statusItem.alternateImage = NSImage(named: "sytemstatusicon_selected")
        statusItem.highlightMode = true
        updateStatusTitle()
        
        statusMenu.delegate = self
        
        // Setup contents
        statusItem.menu = statusMenu
        updateStatusContent(nil)

        let notificationCenter =  NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidReceiveData.rawValue), object: nil)
        notificationCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidSendData.rawValue), object: nil)
        notificationCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: StatusManager.StatusNotifications.DidUpdateStatus.rawValue), object: nil)
    }
    
    func releaseStatusButton() {
        let notificationCenter =  NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidReceiveData.rawValue), object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidSendData.rawValue), object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: StatusManager.StatusNotifications.DidUpdateStatus.rawValue), object: nil)
    }
    
    func statusGeneralAction(_ sender: AnyObject?) {
        
    }
    
    func updateStatus(_ nofitication : Notification?) {
        updateStatusTitle()
        if isMenuOpen {
            updateStatusContent(nil)
        }
    }
    
    func updateStatusTitle() {
        var title : String?
        
        let bleManager = BleManager.sharedInstance
        if let featuredPeripheral = bleManager.blePeripheralConnected {
            if featuredPeripheral.isUartAdvertised() {
                let receivedBytes = featuredPeripheral.uartData.receivedBytes
                let sentBytes = featuredPeripheral.uartData.sentBytes
                
                title = "\(sentBytes)/\(receivedBytes)"
            }
        }
        
        statusItem.title = title
    }
 
    func updateStatusContent(_ notification: Notification?) {
        let bleManager = BleManager.sharedInstance

        let statusText = StatusManager.sharedInstance.statusDescription()
        
        DispatchQueue.main.async(execute: { [unowned self] in            // Execute on main thrad to avoid flickering on macOS Sierra
            
            self.statusMenu.removeAllItems()
            
            // Main Area
            let descriptionItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
            descriptionItem.isEnabled = false
            self.statusMenu.addItem(descriptionItem)
            //        statusMenu.addItem(NSMenuItem(title: isScanning ?"Stop Scanning":"Start Scanning", action: "statusGeneralAction:", keyEquivalent: ""))
            self.statusMenu.addItem(NSMenuItem.separator())
            
            // Connecting/Connected Peripheral
            var featuredPeripheral = bleManager.blePeripheralConnected
            if (featuredPeripheral == nil) {
                featuredPeripheral = bleManager.blePeripheralConnecting
            }
            if let featuredPeripheral = featuredPeripheral {
                let menuItem = self.addPeripheralToSystemMenu(featuredPeripheral)
                menuItem.offStateImage = NSImage(named: "NSMenuOnStateTemplate")
            }
            
            // Discovered Peripherals
            let blePeripheralsFound = bleManager.blePeripherals()
            for identifier in bleManager.blePeripheralFoundAlphabeticKeys() {
                if (identifier != featuredPeripheral?.peripheral.identifier.uuidString) {
                    let blePeripheral = blePeripheralsFound[identifier]!
                    self.addPeripheralToSystemMenu(blePeripheral)
                }
            }
            
            // Uart data
            if let featuredPeripheral = featuredPeripheral {
                // Separator
                self.statusMenu.addItem(NSMenuItem.separator())
                
                // Uart title
                let title = featuredPeripheral.name != nil ? "\(featuredPeripheral.name!) Stats:" : "Stats:"
                let uartTitleMenuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                uartTitleMenuItem.isEnabled = false
                self.statusMenu.addItem(uartTitleMenuItem)
                
                // Stats
                let receivedBytes = featuredPeripheral.uartData.receivedBytes
                let sentBytes = featuredPeripheral.uartData.sentBytes
                
                let uartSentMenuItem = NSMenuItem(title: "Uart Sent: \(sentBytes) bytes", action: nil, keyEquivalent: "")
                let uartReceivedMenuItem = NSMenuItem(title: "Uart Received: \(receivedBytes) bytes", action: nil, keyEquivalent: "")
                
                uartSentMenuItem.indentationLevel = 1
                uartReceivedMenuItem.indentationLevel = 1
                uartSentMenuItem.isEnabled = false
                uartReceivedMenuItem.isEnabled = false
                self.statusMenu.addItem(uartSentMenuItem)
                self.statusMenu.addItem(uartReceivedMenuItem)
            }
            })
    }

    func addPeripheralToSystemMenu(_ blePeripheral: BlePeripheral) -> NSMenuItem {
        let name = blePeripheral.name != nil ? blePeripheral.name! : LocalizationManager.sharedInstance.localizedString("peripherallist_unnamed")
        let menuItem = NSMenuItem(title: name, action: #selector(onClickPeripheralMenuItem(_:)), keyEquivalent: "")
        let identifier = blePeripheral.peripheral.identifier.uuidString
        menuItem.representedObject = identifier
        statusMenu.addItem(menuItem)
        
        return menuItem
    }
    
    func onClickPeripheralMenuItem(_ sender : NSMenuItem) {
        let identifier = sender.representedObject as! String
        StatusManager.sharedInstance.startConnectionToPeripheral(identifier)
        
    }

    // MARK: - NSMenuDelegate
    func menuWillOpen(_ menu: NSMenu) {
        if (menu == statusMenu) {
            isMenuOpen = true
            updateStatusContent(nil)
        }
        else if (menu == peripheralsMenu) {
            let isScanning = BleManager.sharedInstance.isScanning
            startScanningMenuItem.isEnabled = !isScanning
            stopScanningMenuItem.isEnabled = isScanning
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        if (menu == statusMenu) {
            isMenuOpen = false
        }
    }

    // MARK: - Main Menu
    
    @IBAction func onStartScanning(_ sender: AnyObject) {
        BleManager.sharedInstance.startScan()
    }

    @IBAction func onStopScanning(_ sender: AnyObject) {
        BleManager.sharedInstance.stopScan()
    }
    
    @IBAction func onRefreshPeripherals(_ sender: AnyObject) {
        BleManager.sharedInstance.refreshPeripherals()
    }

    /* launch app from menuitem
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [_window makeKeyAndOrderFront:self];
*/
}

