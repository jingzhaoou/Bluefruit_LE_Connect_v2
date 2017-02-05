//
//  StatusManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/10/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

class StatusManager : NSObject {
    static let sharedInstance = StatusManager()
    
    enum StatusNotifications : String {
        case DidUpdateStatus = "didUpdateStatus"
    }
        
    enum Status {
        case updating
        case connected
        case connecting
        case scanning
        case unknown
        case resetting
        case unsupported
        case unauthorized
        case poweredOff
        case ready        
    }
    
    var status = Status.unknown
    
    // Links to controllers needed to determine status
    weak var peripheralListViewController : PeripheralListViewController?
    weak var updateDialogViewController : UpdateDialogViewController?
    
    override init() {
        super.init()
        
        let defaultCenter = NotificationCenter.default
        defaultCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidUpdateBleState.rawValue), object: nil)
        defaultCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidStartScanning.rawValue), object: nil)
        defaultCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillConnectToPeripheral.rawValue), object: nil)
        defaultCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidConnectToPeripheral.rawValue), object: nil)
        defaultCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue), object: nil)
        defaultCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue), object: nil)
        defaultCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidStopScanning.rawValue), object: nil)
        
        defaultCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue), object: nil)
        defaultCenter.addObserver(self, selector: #selector(updateStatus(_:)), name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue), object: nil)
        
    }
    
    deinit {
        let defaultCenter = NotificationCenter.default
        defaultCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidUpdateBleState.rawValue), object: nil)
        defaultCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidStartScanning.rawValue), object: nil)
        defaultCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillConnectToPeripheral.rawValue), object: nil)
        defaultCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidConnectToPeripheral.rawValue), object: nil)
        defaultCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue), object: nil)
        defaultCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue), object: nil)
        defaultCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidStopScanning.rawValue), object: nil)
        defaultCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue), object: nil)
        defaultCenter.removeObserver(self, name: NSNotification.Name(rawValue: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue), object: nil)
    }
    
    func updateStatus(_ notification: Notification) {
        let bleManager = BleManager.sharedInstance
        let isUpdating = updateDialogViewController != nil
        let isConnected = bleManager.blePeripheralConnected != nil
        let isConnecting = bleManager.blePeripheralConnecting != nil
        let isScanning = bleManager.isScanning
        
        if isUpdating {
            status = .updating
        }
        else if isConnected {
            status = .connected
        }
        else if isConnecting {
            status = .connecting
        }
        else if isScanning {
           status = .scanning
        }
        else {
            if let state = bleManager.centralManager?.state {
                
                switch(state) {
                case .unknown:
                    status = .unknown
                case .resetting:
                    status = .resetting
                case .unsupported:
                    status = .unsupported
                case .unauthorized:
                    status = .unauthorized
                case .poweredOff:
                    status = .poweredOff
                case .poweredOn:
                    status = .ready
                }
            }
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: StatusNotifications.DidUpdateStatus.rawValue), object: nil);
    }
    
    func statusDescription() -> String {
        
        var message = ""
        let bleManager = BleManager.sharedInstance
        
        switch status {
        case .updating:
            message = "Updating Firmware"
        case .connected:
            if let name = bleManager.blePeripheralConnected?.name {
                message = "Connected to \(name)"
            }
            else {
                message = "Connected"
            }
        case .connecting:
            if let name = bleManager.blePeripheralConnecting?.name {
                message = "Connecting to \(name)..."
            }
            else {
                message = "Connecting..."
            }
        case .scanning:
            message = "Scanning..."
        case .unknown:
            message = "State unknown, update imminent..."
        case .resetting:
            message = "The connection with the system service was momentarily lost, update imminent..."
        case .unsupported:
            message = "Bluetooth Low Energy unsupported"
        case .unauthorized:
            message = "Unathorized to use Bluetooth Low Energy"
            
        case .poweredOff:
            message = "Bluetooth is currently powered off"
        case .ready:
            message = "Status: Ready"
            
        }
        
        return message
    }
    
    func errorDescription() -> String? {
        var errorMessage: String?
        
        switch status {
        case .unsupported:
            errorMessage = "This computer doesn't support Bluetooth Low Energy"
        case .unauthorized:
            errorMessage = "The application is not authorized to use the Bluetooth Low Energy"
        case .poweredOff:
            errorMessage = "Bluetooth is currently powered off"
        default:
            errorMessage = nil
        }
        
        return errorMessage
    }
    
    func startConnectionToPeripheral(_ identifier: String?) {
        peripheralListViewController?.selectRowForPeripheralIdentifier(identifier)
    }
}
