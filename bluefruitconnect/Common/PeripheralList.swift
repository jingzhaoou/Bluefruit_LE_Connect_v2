//
//  PeripheralList.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 05/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class PeripheralList {
    private var lastUserSelectionTime = CFAbsoluteTimeGetCurrent()
    //private var selectedPeripheralIdentifier: String?
    
    var blePeripherals: [String] {
        return BleManager2.sharedInstance.blePeripheralFoundAlphabeticKeys()
    }
    
    var blePeripheralsCount: Int {
        return BleManager2.sharedInstance.blePeripheralsCount()
    }
    
    /*
    var selectedPeripheralRow: Int? {
        return indexOfPeripheralIdentifier(selectedPeripheralIdentifier)
    }*/
    
    var elapsedTimeSinceSelection: CFAbsoluteTime {
        return CFAbsoluteTimeGetCurrent() - self.lastUserSelectionTime
    }
    
    func indexOfPeripheralIdentifier(identifier : String?) -> Int? {
        var result: Int?
        if let identifier = identifier {
            result = blePeripherals.indexOf(identifier)
        }
        
        return result
    }
    
    func resetUserSelectionTime() {
        lastUserSelectionTime = CFAbsoluteTimeGetCurrent()
    }
    
    /*
    func connectToPeripheral(identifier: String?) {
        let bleManager = BleManager2.sharedInstance
        
        guard let identifier = identifier else {
            selectedPeripheralIdentifier = nil
            return
        }
        
        if let blePeripheral = bleManager.blePeripheralWithUuid(identifier) {
            
            if blePeripheral.state != .Connected {
                // Connect to new peripheral
                bleManager.connect(blePeripheral)
            }
            
            // Select peripheral
            selectedPeripheralIdentifier = identifier
        }
    }
    
    func selectRow(row : Int ) {
        lastUserSelectionTime = CFAbsoluteTimeGetCurrent()

        if (row != selectedPeripheralRow) {
            //DLog("Peripheral selected row: \(row)")
            connectToPeripheral(row >= 0 ? blePeripherals[row]: nil)
        }
    }
 */
}