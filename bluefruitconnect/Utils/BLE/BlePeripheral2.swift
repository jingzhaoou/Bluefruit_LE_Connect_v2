//
//  BlePeripheral2.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/09/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class BlePeripheral2 {

    var peripheral: CBPeripheral!
    var advertisementData: [String : AnyObject]
    var rssi: Int
    var lastSeenTime: CFAbsoluteTime
        
    var name: String? {
        get {
            return peripheral.name
        }
    }
    
    var state: CBPeripheralState {
        get {
            return peripheral.state
        }
    }

    init(peripheral: CBPeripheral,  advertisementData: [String : AnyObject], RSSI: Int) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = RSSI
        self.lastSeenTime = CFAbsoluteTimeGetCurrent()
    }

    // MARK: - Uart
    private static let kUartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"       // UART service UUID
    class UartData {
        var receivedBytes : Int64 = 0
        var sentBytes : Int64 = 0
    }
    var uartData = UartData()
    
    func isUartAdvertised() -> Bool {
        
        var isUartAdvertised = false
        if let serviceUUIds = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            isUartAdvertised = serviceUUIds.contains(CBUUID(string: BlePeripheral2.kUartServiceUUID))
        }
        return isUartAdvertised
    }
    
    func hasUart() -> Bool {
        var hasUart = false
        if let services = peripheral.services {
            hasUart = services.contains({ (service : CBService) -> Bool in
                service.UUID.isEqual(CBUUID(string: BlePeripheral2.kUartServiceUUID))
            })
        }
        return hasUart
    }
    
    
}
