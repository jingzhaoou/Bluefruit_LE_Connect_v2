//
//  BleManager.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


class BleManager : NSObject, CBCentralManagerDelegate {
    
    // Configuration
    static let kStopScanningWhenConnectingToPeripheral = false
    static let kUseBakgroundQueue = true
    static let kAlwaysAllowDuplicateKeys = true
    
    static let kIsUndiscoverPeripheralsEnabled = false                   // If true, the BleManager will check periodically if devices are no longer in range (warning: this could cause problems if for some peripherals that dont update its status for a long time)
    static let kUndiscoverCheckPeriod = 1.0                             // in seconds
    static let kUndiscoverPeripheralConsideredOutOfRangeTime = 50.0      // in seconds
    
    // Notifications
    enum BleNotifications : String {
        case DidUpdateBleState = "didUpdateBleState"
        case DidStartScanning = "didStartScanning"
        case DidStopScanning = "didStopScanning"
        case DidDiscoverPeripheral = "didDiscoverPeripheral"
        case DidUnDiscoverPeripheral = "didUnDiscoverPeripheral"
        case WillConnectToPeripheral = "willConnectToPeripheral"
        case DidConnectToPeripheral = "didConnectToPeripheral"
        case WillDisconnectFromPeripheral = "willDisconnectFromPeripheral"
        case DidDisconnectFromPeripheral = "didDisconnectFromPeripheral"
    }
    
    // Main
    static let sharedInstance = BleManager()
    var centralManager: CBCentralManager?
    
    // Scanning
    var isScanning = false
    var wasScanningBeforeBluetoothOff = false
    fileprivate var blePeripheralsFound = [String : BlePeripheral]()
    var blePeripheralConnecting: BlePeripheral?
    var blePeripheralConnected: BlePeripheral?             // last peripheral connected (note: only one peripheral can can be connected at the same time
    var undiscoverTimer: Timer?
    
    //
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: BleManager.kUseBakgroundQueue ? DispatchQueue.global(qos: DispatchQoS.QoSClass.background) : nil)
    }
    
    func restoreCentralManager() {
        // Restore central manager delegate if was changed
        centralManager?.delegate = self
    }
    
    func startScan() {
        guard let centralManager = centralManager, centralManager.state != .poweredOff && centralManager.state != .unauthorized && centralManager.state != .unsupported else {
            DLog("startScan failed because central manager is not ready")
            return
        }
        
        guard centralManager.state == .poweredOn else {
            wasScanningBeforeBluetoothOff = true    // set true to start scanning as soon as bluetooth is powered on
            return
        }
                
        //DLog("startScan")
        isScanning = true
        wasScanningBeforeBluetoothOff = true
        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.DidStartScanning.rawValue), object: nil)
        if (BleManager.kIsUndiscoverPeripheralsEnabled) {
            undiscoverTimer = Timer.scheduledTimer(timeInterval: BleManager.kUndiscoverCheckPeriod, target: self, selector:#selector(BleManager.checkUndiscoveredPeripherals), userInfo: nil, repeats: true)
        }
        
        let allowDuplicateKeys = BleManager.kAlwaysAllowDuplicateKeys || BleManager.kIsUndiscoverPeripheralsEnabled
        let scanOptions = allowDuplicateKeys ? [CBCentralManagerScanOptionAllowDuplicatesKey : true as AnyObject] as [String: AnyObject]? : nil
        centralManager.scanForPeripherals(withServices: nil, options: scanOptions)
    }
    
    func stopScan() {
        //DLog("stopScan")
        
        centralManager?.stopScan()
        isScanning = false
        wasScanningBeforeBluetoothOff = false
        if (BleManager.kIsUndiscoverPeripheralsEnabled) {
            undiscoverTimer?.invalidate()
            undiscoverTimer = nil
        }
        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.DidStopScanning.rawValue), object: nil)
    }
    
    func refreshPeripherals() {
        stopScan()
        
        synchronize(blePeripheralsFound as AnyObject) {
            self.blePeripheralsFound.removeAll()
            
            // Don't remove connnected or connecting peripherals
            if let connected = self.blePeripheralConnected {
                self.blePeripheralsFound[connected.peripheral.identifier.uuidString] = connected
            }
            if let connecting = self.blePeripheralConnecting {
                self.blePeripheralsFound[connecting.peripheral.identifier.uuidString] = connecting
            }
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.DidUnDiscoverPeripheral.rawValue), object: nil)
        startScan()
    }
    
    
    func connect(_ blePeripheral: BlePeripheral) {
        
        // Stop scanning when connecting to a peripheral (to improve discovery time)
        if (BleManager.kStopScanningWhenConnectingToPeripheral) {
            stopScan()
        }
        
        // Connect
        blePeripheralConnecting = blePeripheral
       // DLog("connecting to: \(blePeripheral.name)")
        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.WillConnectToPeripheral.rawValue), object: nil, userInfo: ["uuid" : blePeripheral.peripheral.identifier.uuidString])
        
        centralManager?.connect(blePeripheral.peripheral, options: nil)
    }
    
    
    func disconnect(_ blePeripheral: BlePeripheral) {
        
       // DLog("disconnecting from: \(blePeripheral.name)")
        blePeripheralConnecting = nil
        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.WillDisconnectFromPeripheral.rawValue), object: nil, userInfo: ["uuid" : blePeripheral.peripheral.identifier.uuidString])
        centralManager?.cancelPeripheralConnection(blePeripheral.peripheral)
    }
    
    func discover(_ blePeripheral : BlePeripheral, serviceUUIDs: [CBUUID]?) {
        DLog("discover services")
        blePeripheral.peripheral.discoverServices(serviceUUIDs)
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DLog("centralManagerDidUpdateState \(central.state.rawValue)")
        
        if (central.state == .poweredOn) {
            if (wasScanningBeforeBluetoothOff) {
                startScan()        // Continue scanning now that bluetooth is back
            }
        }
        else {
            if let blePeripheralConnected = blePeripheralConnected {
                DLog("Bluetooth is not powered on. Disconnect connected peripheral")
                blePeripheralConnecting = nil
                disconnect(blePeripheralConnected)
            }
            
            isScanning = false
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.DidUpdateBleState.rawValue), object: nil, userInfo: ["state" : central.state.rawValue])
    }
    
    func checkUndiscoveredPeripherals() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        synchronize(blePeripheralsFound as AnyObject) {
            for (identifier, blePeripheral) in self.blePeripheralsFound {
                if identifier != self.blePeripheralConnected?.peripheral.identifier.uuidString { // Don't hide the connected peripheral
                    let elapsedTime = currentTime - blePeripheral.lastSeenTime
                    if elapsedTime > BleManager.kUndiscoverPeripheralConsideredOutOfRangeTime {
                        DLog("undiscovered peripheral: \(blePeripheral.name)")
                        self.blePeripheralsFound.removeValue(forKey: identifier)
                        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.DidUnDiscoverPeripheral.rawValue), object: nil, userInfo: ["uuid" : identifier])
                    }
                }
                //            let elapsedFormatted = String(format:"%.2f", elapsedTime)
                //            DLog("peripheral \(blePeripheral.name): elapsed \( elapsedFormatted )")
            }
        }
        
        // DLog("--")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        let identifierString = peripheral.identifier.uuidString
        //DLog("didDiscoverPeripheral \(peripheral.name)")
        synchronize(blePeripheralsFound as AnyObject) {
            if let existingPeripheral = self.blePeripheralsFound[identifierString] {
                // Existing peripheral. Update advertisement data because each time is discovered the advertisement data could miss some of the keys (sometimes a sevice is there, and other times has dissapeared)
                
                existingPeripheral.rssi = RSSI.intValue
                existingPeripheral.lastSeenTime = CFAbsoluteTimeGetCurrent()
                for (key, value) in advertisementData {
                    existingPeripheral.advertisementData.updateValue(value as AnyObject, forKey: key)
                }
                self.blePeripheralsFound[identifierString] = existingPeripheral
                
            }
            else {      // New peripheral found
                //DLog("New peripheral found: \(identifierString) - \(peripheral.name != nil ? peripheral.name!:"")")
                let blePeripheral = BlePeripheral(peripheral: peripheral, advertisementData: advertisementData as [String : AnyObject], RSSI: RSSI.intValue)
                self.blePeripheralsFound[identifierString] = blePeripheral
            }
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.DidDiscoverPeripheral.rawValue), object:nil, userInfo: ["uuid" : identifierString])
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        //DLog("didConnectPeripheral: \(peripheral.name != nil ? peripheral.name! : "")")
        
        blePeripheralConnecting = nil
        let identifier = peripheral.identifier.uuidString
        synchronize(blePeripheralsFound as AnyObject) {
            self.blePeripheralConnected = self.blePeripheralsFound[identifier]
        }
        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.DidConnectToPeripheral.rawValue), object: nil, userInfo: ["uuid" : identifier])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DLog("didDisconnectPeripheral: \(peripheral.name != nil ? peripheral.name! : "")")
        
        peripheral.delegate = nil
        if peripheral.identifier == blePeripheralConnected?.peripheral.identifier {
            self.blePeripheralConnected = nil
        }
        self.blePeripheralConnecting = nil
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.DidDisconnectFromPeripheral.rawValue), object: nil,  userInfo: ["uuid" : peripheral.identifier.uuidString])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DLog("didFailToConnectPeripheral: \(peripheral.name != nil ? peripheral.name! : "")")
        
        blePeripheralConnecting = nil
        NotificationCenter.default.post(name: Notification.Name(rawValue: BleNotifications.DidDisconnectFromPeripheral.rawValue), object: nil,  userInfo: ["uuid" : peripheral.identifier.uuidString])
    }
    
    // MARK: - Utils
    func blePeripherals() -> [String : BlePeripheral] {         // To avoid race conditions when modifying the array
        var result: [String : BlePeripheral]?
        synchronize(blePeripheralsFound as AnyObject) { [unowned self] in
            result = self.blePeripheralsFound
        }
        
        return result!
    }
    
    func blePeripheralsCount() -> Int {                          // To avoid race conditions when modifying the array
        var result = 0
        
        synchronize(blePeripheralsFound as AnyObject) { [unowned self] in
            result = self.blePeripheralsFound.count
        }
        
        return result
    }
    
    func blePeripheralFoundAlphabeticKeys() -> [String] {
        // Sort blePeripheralsFound keys alphabetically and return them as an array
        
        var sortedKeys : [String] = []
        synchronize(blePeripheralsFound as AnyObject) {
            sortedKeys = Array(self.blePeripheralsFound.keys).sorted(by: {[weak self] in self?.blePeripheralsFound[$0]?.name < self?.blePeripheralsFound[$1]?.name})
        }
        return sortedKeys
    }
}
