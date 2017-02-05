//
//  PeripheralList.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 05/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class PeripheralList {
    fileprivate var lastUserSelectionTime = CFAbsoluteTimeGetCurrent()
    fileprivate var selectedPeripheralIdentifier: String?
    
    var filterName: String? = Preferences.scanFilterName {
        didSet {
            Preferences.scanFilterName = filterName
            isFilterDirty = true
        }
    }
    var isFilterNameExact = Preferences.scanFilterIsNameExact {
        didSet {
            Preferences.scanFilterIsNameExact = isFilterNameExact
            isFilterDirty = true
        }
    }
    var isFilterNameCaseInsensitive = Preferences.scanFilterIsNameCaseInsensitive {
        didSet {
            Preferences.scanFilterIsNameCaseInsensitive = isFilterNameCaseInsensitive
            isFilterDirty = true
        }
    }
    var rssiFilterValue: Int? = Preferences.scanFilterRssiValue {
        didSet {
            Preferences.scanFilterRssiValue = rssiFilterValue
            isFilterDirty = true
        }
    }
    var isUnnamedEnabled = Preferences.scanFilterIsUnnamedEnabled {
        didSet {
            Preferences.scanFilterIsUnnamedEnabled = isUnnamedEnabled
            isFilterDirty = true
        }
    }
    var isOnlyUartEnabled = Preferences.scanFilterIsOnlyWithUartEnabled {
        didSet {
            Preferences.scanFilterIsOnlyWithUartEnabled = isOnlyUartEnabled
            isFilterDirty = true
        }
    }
    
    fileprivate var isFilterDirty = true
   
    fileprivate var cachedFilteredPeripherals: [String] = []
    
    
    func setDefaultFilters() {
        filterName = nil
        isFilterNameExact = false
        isFilterNameCaseInsensitive = true
        rssiFilterValue = nil
        isUnnamedEnabled = true
        isOnlyUartEnabled = false
    }
    
    func isAnyFilterEnabled() -> Bool {
        return (filterName != nil && !filterName!.isEmpty) || rssiFilterValue != nil || isOnlyUartEnabled || !isUnnamedEnabled
    }
    
    func filteredPeripherals(_ forceUpdate: Bool) -> [String] {
        if isFilterDirty || forceUpdate {
            cachedFilteredPeripherals = calculateFilteredPeripherals()
            isFilterDirty = false
        }
        return cachedFilteredPeripherals
    }
    
    fileprivate func calculateFilteredPeripherals() -> [String] {
        var peripherals = BleManager.sharedInstance.blePeripheralFoundAlphabeticKeys()
        
        let bleManager = BleManager.sharedInstance
        let blePeripheralsFound = bleManager.blePeripherals()
        
        // Apply filters
        if isOnlyUartEnabled {
            peripherals = peripherals.filter({blePeripheralsFound[$0]?.isUartAdvertised() ?? false})
        }
        
        if !isUnnamedEnabled {
            peripherals = peripherals.filter({blePeripheralsFound[$0]?.name != nil})
        }
        
        if let filterName = filterName, !filterName.isEmpty {
            peripherals = peripherals.filter({ identifier -> Bool in
                if let name = blePeripheralsFound[identifier]?.name {
                    let compareOptions = isFilterNameCaseInsensitive ? NSString.CompareOptions.caseInsensitive: NSString.CompareOptions()
                    if isFilterNameExact {
                        return name.compare(filterName, options: compareOptions, range: nil, locale: nil) == .orderedSame
                    }
                    else {
                        return name.range(of: filterName, options: compareOptions, range: nil, locale: nil) != nil
                    }
                }
                else {
                    return false
                }
            })
        }
        
        if let rssiFilterValue = rssiFilterValue {
            peripherals = peripherals.filter({ identifier -> Bool in
                if let rssi = blePeripheralsFound[identifier]?.rssi {
                    let validRssi = rssi >= rssiFilterValue
                    return validRssi
                }
                else {
                    return false
                }
            })
        }

        return peripherals
    }
    
    func filtersDescription() -> String? {
        var filtersTitle: String?
        if let filterName = filterName, !filterName.isEmpty {
            filtersTitle = filterName
        }
        
        if let rssiFilterValue = rssiFilterValue {
            let rssiString = "Rssi >= \(rssiFilterValue)"
            if filtersTitle != nil && !filtersTitle!.isEmpty {
                filtersTitle!.append(", \(rssiString)")
            }
            else {
                filtersTitle = rssiString
            }
        }
        
        if !isUnnamedEnabled {
            let namedString = "with name"
            if filtersTitle != nil && !filtersTitle!.isEmpty {
                filtersTitle!.append(", \(namedString)")
            }
            else {
                filtersTitle = namedString
            }
        }
        
        if isOnlyUartEnabled {
            let uartString = "with UART"
            if filtersTitle != nil && !filtersTitle!.isEmpty {
                filtersTitle!.append(", \(uartString)")
            }
            else {
                filtersTitle = uartString
            }
        }
        
        return filtersTitle
    }
    
    
    var selectedPeripheralRow: Int? {
        return indexOfPeripheralIdentifier(selectedPeripheralIdentifier)
    }
    
    var elapsedTimeSinceSelection: CFAbsoluteTime {
        return CFAbsoluteTimeGetCurrent() - self.lastUserSelectionTime
    }
    
    func indexOfPeripheralIdentifier(_ identifier: String?) -> Int? {
        var result : Int?
        if let identifier = identifier {
            result = cachedFilteredPeripherals.index(of: identifier)
        }
        
        return result
    }
    
    func disconnected() {
        // Check that is really disconnected
        if BleManager.sharedInstance.blePeripheralConnected == nil {
            selectedPeripheralIdentifier = nil
           // DLog("Peripheral selected row: -1")
            
        }
    }
    
    func connectToPeripheral(_ identifier: String?) {
        let bleManager = BleManager.sharedInstance
        
        if (identifier != bleManager.blePeripheralConnected?.peripheral.identifier.uuidString || identifier == nil) {
            
            //
            let blePeripheralsFound = bleManager.blePeripherals()
            lastUserSelectionTime = CFAbsoluteTimeGetCurrent()
            
            // Disconnect from previous
            if let selectedRow = selectedPeripheralRow {
                let peripherals = cachedFilteredPeripherals
                if selectedRow < peripherals.count {      // To avoid problems with peripherals disconnecting
                    let selectedBlePeripheralIdentifier = peripherals[selectedRow];
                    let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
                    
                    BleManager.sharedInstance.disconnect(blePeripheral)
                }
                //DLog("Peripheral selected row: -1")
                selectedPeripheralIdentifier = nil
            }
            
            // Connect to new peripheral
            if let selectedBlePeripheralIdentifier = identifier {
                
                let blePeripheral = blePeripheralsFound[selectedBlePeripheralIdentifier]!
                if (BleManager.sharedInstance.blePeripheralConnected?.peripheral.identifier.uuidString != selectedBlePeripheralIdentifier) {
                    // DLog("connect to new peripheral: \(selectedPeripheralIdentifier)")
                    
                    BleManager.sharedInstance.connect(blePeripheral)
                    
                    selectedPeripheralIdentifier = selectedBlePeripheralIdentifier
                }
            }
            else {
                //DLog("Peripheral selected row: -1")
                selectedPeripheralIdentifier = nil;
            }
        }
    }
    
    func selectRow(_ row: Int) {
        if (row != selectedPeripheralRow) {
            //DLog("Peripheral selected row: \(row)")
            connectToPeripheral(row >= 0 ? cachedFilteredPeripherals[row] : nil)
        }
    }
}
