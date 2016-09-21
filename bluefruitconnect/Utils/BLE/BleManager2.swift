//
//  BleManager2.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/09/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

@objc protocol BlePeripheralsDelegate {
    optional func peripheralDidUpdateName(peripheral: CBPeripheral)
}

class BleManager2: NSObject {
    // Configuration
    static let kStopScanningWhenConnectingToPeripheral = false
    static let kUseBakgroundQueue = true
    static let kAlwaysAllowDuplicateKeys = true

    // Notifications
    enum BleNotifications: String {
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
    static let sharedInstance = BleManager2()
    var centralManager: CBCentralManager?

    // Scanning
    var isScanning = false
    var wasScanningBeforeBluetoothOff = false
    private var blePeripheralsFound = [String: BlePeripheral2]()

    // Delegate
    weak var peripheralsDelegate: BlePeripheralsDelegate?
    
    //
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: BleManager.kUseBakgroundQueue ? dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0) : nil)
    }
    
    // MARK: - Scan
    func startScan() {
        guard let centralManager = centralManager where centralManager.state != .PoweredOff && centralManager.state != .Unauthorized && centralManager.state != .Unsupported else {
            DLog("startScan failed because central manager is not ready")
            return
        }

        //DLog("startScan");
        isScanning = true
        wasScanningBeforeBluetoothOff = true
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidStartScanning.rawValue, object: nil)
        let allowDuplicateKeys = BleManager.kAlwaysAllowDuplicateKeys
        let scanOptions = allowDuplicateKeys ? [CBCentralManagerScanOptionAllowDuplicatesKey: true] as [String: AnyObject]? : nil
        centralManager.scanForPeripheralsWithServices(nil, options: scanOptions)
    }

    func stopScan() {
        //DLog("stopScan");
        
        centralManager?.stopScan()
        isScanning = false
        wasScanningBeforeBluetoothOff = false
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidStopScanning.rawValue, object: nil)
    }
    
    func refreshPeripherals() {
        stopScan()
        
        synchronize(blePeripheralsFound) {
            for blePeripheral in self.blePeripheralsFound.reverse() {
                // Don't remove connnected or connecting peripherals
                if blePeripheral.1.state == .Disconnected {
                    self.blePeripheralsFound.removeValueForKey(blePeripheral.0)
                }
            }
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil);
        startScan()
    }

    
    func connectedPeripherals()-> [(String, BlePeripheral2)] {
        return blePeripheralsFound.filter({$0.1.state == .Connected})
    }
    
    func connectingPeripherals() -> [(String, BlePeripheral2)] {
        return blePeripheralsFound.filter({$0.1.state == .Connecting})
    }
    
    // MARK: - Connection Management
    
    func connect(blePeripheral: BlePeripheral2) {
        
        // Stop scanning when connecting to a peripheral (to improve discovery time)
        if (BleManager.kStopScanningWhenConnectingToPeripheral) {
            stopScan()
        }
        
        // Connect
        // DLog("connecting to: \(blePeripheral.name)")
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.WillConnectToPeripheral.rawValue, object: nil, userInfo: ["uuid" : blePeripheral.peripheral.identifier.UUIDString])
        
        centralManager?.connectPeripheral(blePeripheral.peripheral, options: nil)
    }
    
    func disconnect(blePeripheral: BlePeripheral2) {
        
        // DLog("disconnecting from: \(blePeripheral.name)")
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil, userInfo: ["uuid" : blePeripheral.peripheral.identifier.UUIDString])
        centralManager?.cancelPeripheralConnection(blePeripheral.peripheral)
    }
    
    // MARK: - Utils
    func restoreCentralManager() {
        // Restore central manager delegate if was changed
        centralManager?.delegate = self
    }
    

    func blePeripherals() -> [String: BlePeripheral2] {         // To avoid race conditions when modifying the array
        var result: [String: BlePeripheral2]?
        synchronize(blePeripheralsFound) { [unowned self] in
            result = self.blePeripheralsFound
        }
        
        return result!
    }
    
    func blePeripheralWithUuid(uuid: String) -> BlePeripheral2? {
        let peripherals = blePeripherals()
        return peripherals[uuid]
    }
    
    func blePeripheralsCount() -> Int {                          // To avoid race conditions when modifying the array
        var result = 0
        
        synchronize(blePeripheralsFound) { [unowned self] in
            result = self.blePeripheralsFound.count
        }
        
        return result
    }
    
    func blePeripheralFoundAlphabeticKeys() -> [String] {
        // Sort blePeripheralsFound keys alphabetically and return them as an array
        
        var sortedKeys: [String] = []
        synchronize(blePeripheralsFound) {
            sortedKeys = Array(self.blePeripheralsFound.keys).sort({[weak self] in self?.blePeripheralsFound[$0]?.name < self?.blePeripheralsFound[$1]?.name})
        }
        return sortedKeys
    }

}

// MARK: - CBCentralManagerDelegate
extension BleManager2: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(central: CBCentralManager) {
        DLog("centralManagerDidUpdateState \(central.state.rawValue)")
        
        if (central.state == .PoweredOn) {
            if (wasScanningBeforeBluetoothOff) {
                startScan();        // Continue scanning now that bluetooth is back
            }
        }
        else {
            DLog("Bluetooth is not powered on. Disconnect connected peripheral")
            
            for blePeripheral in blePeripheralsFound.values {
                disconnect(blePeripheral)
            }
            
            isScanning = false
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidUpdateBleState.rawValue, object: nil, userInfo: ["state" : central.state.rawValue])
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral,  advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        let identifierString = peripheral.identifier.UUIDString
        // DLog("didDiscoverPeripheral \(peripheral.name != nil ?  peripheral.name! : "{No Name}")")
        synchronize(blePeripheralsFound) {
            if let existingPeripheral = self.blePeripheralsFound[identifierString] {
                // Existing peripheral. Update advertisement data because each time is discovered the advertisement data could miss some of the keys (sometimes a service is there, and other times it has dissapeared)
                
                existingPeripheral.rssi = RSSI.integerValue
                existingPeripheral.lastSeenTime = CFAbsoluteTimeGetCurrent()
                for (key, value) in advertisementData {
                    existingPeripheral.advertisementData.updateValue(value, forKey: key);
                }
                self.blePeripheralsFound[identifierString] = existingPeripheral
                
            }
            else {      // New peripheral found
                //DLog("New peripheral found: \(identifierString) - \(peripheral.name != nil ? peripheral.name!:"")")
                let blePeripheral = BlePeripheral2(peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI.integerValue)
                self.blePeripheralsFound[identifierString] = blePeripheral
            }
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDiscoverPeripheral.rawValue, object:nil, userInfo: ["uuid" : identifierString]);
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        //DLog("didConnectPeripheral: \(peripheral.name != nil ? peripheral.name! : "")")
        
        let identifier = peripheral.identifier.UUIDString
        peripheral.delegate = self
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidConnectToPeripheral.rawValue, object: nil, userInfo: ["uuid" : identifier])
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        //DLog("didDisconnectPeripheral: \(peripheral.name != nil ? peripheral.name! : "")")
        
        peripheral.delegate = nil
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil,  userInfo: ["uuid" : peripheral.identifier.UUIDString])
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        DLog("didFailToConnectPeripheral: \(peripheral.name != nil ? peripheral.name! : "")")
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil,  userInfo: ["uuid" : peripheral.identifier.UUIDString])
    }

}

// MARK: - CBPeripheralDelegate
extension BleManager2: CBPeripheralDelegate {
    
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        peripheralsDelegate?.peripheralDidUpdateName?(peripheral)
    }
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
    }
    
    func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
    }

    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
    }
    
   
}

