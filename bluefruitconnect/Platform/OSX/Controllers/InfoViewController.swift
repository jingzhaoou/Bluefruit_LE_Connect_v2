//
//  InfoViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 25/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
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

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class InfoViewController: NSViewController {
    // Config
    fileprivate static let kExpandAllNodes  = true
    fileprivate static let kReadForbiddenCCCD = false     // Added to avoid generating a didModifyServices callback when reading Uart/DFU CCCD (bug??)
    
    // UI
    @IBOutlet weak var baseTableView: NSOutlineView!
    @IBOutlet weak var refreshOnLoadButton: NSButton!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var discoveringStatusLabel: NSTextField!
    
    // Delegates
    var onServicesDiscovered : (() -> ())?
    var onInfoScanFinished : (() -> ())?
    
    // Data
    fileprivate var blePeripheral : BlePeripheral?
    fileprivate var services : [CBService]?
    
    fileprivate var shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled

    fileprivate var isDiscoveringServices = false
    fileprivate var elementsToDiscover = 0
    fileprivate var elementsDiscovered = 0
    fileprivate var valuesToRead = 0
    fileprivate var valuesRead = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        refreshOnLoadButton.state = Preferences.infoIsRefreshOnLoadEnabled ? NSOnState : NSOffState
    }
    
    func discoverServices() {
        isDiscoveringServices = true
        elementsToDiscover = 0
        elementsDiscovered = 0
        valuesToRead = 0
        valuesRead = 0
        updateDiscoveringStatus()
        
        services = nil
        self.baseTableView.reloadData()
        BleManager.sharedInstance.discover(blePeripheral!, serviceUUIDs: nil)
    }

    func updateDiscoveringStatus() {
        
        //DLog("Discovering (\(elementsDiscovered)/\(elementsToDiscover)) and reading values (\(valuesRead)/\(valuesToRead))...")
        
        if !isDiscoveringAndUpdatingInitialValues() {
            onInfoScanFinished?()
        }
        
        var text = ""
        if isDiscoveringServices {
            text = "Discovering Services..."
            refreshButton.isEnabled = false
        }
        else if elementsDiscovered < elementsToDiscover || valuesRead < valuesToRead {
            if shouldDiscoverCharacteristics {
                text = "Discovering (\(elementsDiscovered)/\(elementsToDiscover)) and reading values (\(valuesRead)/\(valuesToRead))..."
            }
            else {
                text = "Discovering (\(elementsDiscovered)/\(elementsToDiscover))..."
            }
            refreshButton.isEnabled = false
        }
        else {
            refreshButton.isEnabled = true
        }
        
        discoveringStatusLabel.stringValue = text
    }
    
    
    fileprivate func isDiscoveringAndUpdatingInitialValues() -> Bool {
        return isDiscoveringServices || elementsDiscovered < elementsToDiscover || valuesRead < valuesToRead
    }

    
    // MARK: - Actions
    @IBAction func onClickRefreshOnLoad(_ sender: NSButton) {
        Preferences.infoIsRefreshOnLoadEnabled = sender.state == NSOnState
    }
    
    @IBAction func onClickRefresh(_ sender: AnyObject) {
        shouldDiscoverCharacteristics = true
        discoverServices()
    }
}

// MARK: - DetailTab
extension InfoViewController : DetailTab {
    
    func tabWillAppear() {
        updateDiscoveringStatus()
        baseTableView.reloadData()
    }
    
    func tabWillDissapear() {
    }
    
    func tabReset() {
        // Peripheral should be connected
        blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        if (blePeripheral == nil) {
            DLog("Error: Info: blePeripheral is nil")
        }
        
        shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled
        updateDiscoveringStatus()
        
        // Discover services
        services = nil
        discoverServices()
    }
    
}

// MARK: - NSOutlineViewDataSource
extension InfoViewController : NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if (item == nil) {
            // Services
            if let services = services {
                return services.count
            }
            else {
                return 0
            }
        }
        else if let service = item as? CBService {
            return service.characteristics == nil ?0:service.characteristics!.count
        }
        else if let characteristic = item as? CBCharacteristic {
            return characteristic.descriptors == nil ?0:characteristic.descriptors!.count
        }
        else {
            return 0
        }
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let service = item as? CBService {
            return service.characteristics?.count > 0
        }
        else if let characteristic = item as? CBCharacteristic {
            return characteristic.descriptors?.count > 0
        }
        else {
            return false
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if (item == nil) {
            return services![index]
        }
        else if let service = item as? CBService {
            return service.characteristics![index]
        }
        else if let characteristic = item as? CBCharacteristic {
            return characteristic.descriptors![index]
        }
        else {
            return "<Unknown>"
        }
    }
}

// MARK: NSOutlineViewDelegate

extension InfoViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        
        var cell = NSTableCellView()
        
        if let columnIdentifier = tableColumn?.identifier {
            switch(columnIdentifier) {
            case "UUIDColumn":
                cell = outlineView.make(withIdentifier: "InfoNameCell", owner: self) as! NSTableCellView
                
                var identifier = ""
                if let service = item as? CBService {
                    identifier = service.uuid.uuidString
                }
                else if let characteristic = item as? CBCharacteristic {
                    identifier = characteristic.uuid.uuidString
                }
                else if let descriptor = item as? CBDescriptor {
                    identifier = descriptor.uuid.uuidString
                }
                
                if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
                    identifier = name
                }
                cell.textField?.stringValue = identifier
            
            case "ValueStringColumn":
                cell = outlineView.make(withIdentifier: "InfoValueStringCell", owner: self) as! NSTableCellView
                var value : String = ""
                if let characteristic = item as? CBCharacteristic {
                    if let characteristicValue = characteristic.value {
                        if let characteristicString = NSString(data: characteristicValue, encoding: String.Encoding.utf8.rawValue) as String? {
                            value = characteristicString
                        }
                    }
                }
                else if let descriptor = item as? CBDescriptor {
                    if let descriptorValue = InfoModuleManager.parseDescriptorValue(descriptor) {//descriptor.value as? NSData{
                        if let descriptorString = NSString(data: descriptorValue, encoding: String.Encoding.utf8.rawValue) as String? {
                            value = descriptorString
                        }
                    }
                }
                
                cell.textField?.stringValue = value
                
            case "ValueHexColumn":
                cell = outlineView.make(withIdentifier: "InfoValueHexCell", owner: self) as! NSTableCellView
                var value : String = ""
                if let characteristic = item as? CBCharacteristic {
                    if let characteristicValue = characteristic.value {
                        value = hexString(characteristicValue)
                    }
                }
                else if let descriptor = item as? CBDescriptor {
                    if let descriptorValue = InfoModuleManager.parseDescriptorValue(descriptor) {//descriptor.value as? NSData{
                        value = hexString(descriptorValue)
                    }
                }
                
                cell.textField?.stringValue = value
                
            case "TypeColumn":
                cell = outlineView.make(withIdentifier: "InfoTypeCell", owner: self) as! NSTableCellView
                
                var type = "<Unknown Type>"
                if let _ = item as? CBService {
                    type = "Service"
                }
                else if let _ = item as? CBCharacteristic {
                    type = "Characteristic"
                }
                else if let _ = item as? CBDescriptor {
                    type = "Descriptor"
                }
                cell.textField?.stringValue = type
                
            default:
                cell.textField?.stringValue = ""
            }
        }
        
        return cell
    }
}

// MARK: - CBPeripheralDelegate
extension InfoViewController : CBPeripheralDelegate {
    
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        DLog("centralManager peripheralDidUpdateName: \(peripheral.name != nil ? peripheral.name! : "")")
        DispatchQueue.main.async(execute: { [weak self] in
            self?.discoverServices()
            })
    }
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog("centralManager didModifyServices: \(peripheral.name != nil ? peripheral.name! : "")")
        
        DispatchQueue.main.async(execute: { [weak self] in
            self?.discoverServices()
            })
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        isDiscoveringServices = false
        
        if services == nil {
            //DLog("centralManager didDiscoverServices: \(peripheral.name != nil ? peripheral.name! : "")")
            
            services = blePeripheral?.peripheral.services
            elementsToDiscover = 0
            elementsDiscovered = 0
            
            // Order services so "DIS" is at the top (if present)
            let kDisServiceUUID = "180A"    // DIS service UUID
            if let unorderedServices = services {
                services = unorderedServices.sorted(by: { (serviceA, serviceB) -> Bool in
                    let isServiceBDis = serviceB.uuid.isEqual(CBUUID(string: kDisServiceUUID))
                    return !isServiceBDis
                })
            }
            
            // Discover characteristics
            if shouldDiscoverCharacteristics {
                if let services = services {
                    for service in services {
                        elementsToDiscover += 1
                        DLog("Discover characteristics for service: \(service.uuid)")
                        blePeripheral?.peripheral.discoverCharacteristics(nil, for: service)
                    }
                }
            }
            
            // Update UI
            DispatchQueue.main.async(execute: { [unowned self] in
                
                self.updateDiscoveringStatus()
                self.baseTableView.reloadData()
                self.onServicesDiscovered?()
                })
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        //DLog("centralManager didDiscoverCharacteristicsForService: \(service.UUID.UUIDString)")
        
        elementsDiscovered += 1
        DLog("Discovered characteristics for service: \(service.uuid)")
        
        var discoveringDescriptors = false
        if let characteristics = service.characteristics {
            if (characteristics.count > 0)  {
                discoveringDescriptors = true
            }
            for characteristic in characteristics {
                if (characteristic.properties.rawValue & CBCharacteristicProperties.read.rawValue != 0) {
                    valuesToRead += 1
                    DLog("Read characteristic: \(characteristic.uuid) for service: \(service.uuid)")
                    peripheral.readValue(for: characteristic)
                }
                
                //elementsToDiscover += 1       // Dont add descriptors to elementsToDiscover because the number of descriptors found is unknown
                blePeripheral?.peripheral.discoverDescriptors(for: characteristic)
            }
        }
        
        DispatchQueue.main.async(execute: { [unowned self] in
            self.updateDiscoveringStatus()
            self.baseTableView.reloadData()
            if (!discoveringDescriptors && InfoViewController.kExpandAllNodes) {
                // Expand all nodes if not waiting for descriptors
                self.baseTableView.expandItem(nil, expandChildren: true)
            }
            })
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        //DLog("centralManager didDiscoverDescriptorsForCharacteristic: \(characteristic.UUID.UUIDString)")
        //elementsDiscovered += 1
        
        if let descriptors = characteristic.descriptors {
            for descriptor in descriptors {
                
                let isAForbiddenCCCD = descriptor.uuid.uuidString.caseInsensitiveCompare("2902") == .orderedSame && (characteristic.uuid.uuidString.caseInsensitiveCompare(UartManager.RxCharacteristicUUID) == .orderedSame || characteristic.uuid.uuidString.caseInsensitiveCompare(dfuControlPointCharacteristicUUIDString) == .orderedSame)
                if InfoViewController.kReadForbiddenCCCD || !isAForbiddenCCCD {
                    DLog("Read descritor: \(descriptor.uuid.uuidString) for characteristic: \(characteristic.uuid.uuidString)")
                    
                    valuesToRead += 1
                    peripheral.readValue(for: descriptor)
                }
            }
        }

        DispatchQueue.main.async(execute: { [unowned self] in
            self.updateDiscoveringStatus()
            self.baseTableView.reloadData()
            
            if (InfoViewController.kExpandAllNodes) {
                // Expand all nodes
                self.baseTableView.expandItem(nil, expandChildren: true)
            }
            })
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //DLog("centralManager didUpdateValueForCharacteristic: \(characteristic.UUID.UUIDString)")
        valuesRead += 1
        
        DLog("Read value for characteristic: \(characteristic.uuid) for service: \(characteristic.service.uuid)")
        DispatchQueue.main.async(execute: { [unowned self] in
            self.updateDiscoveringStatus()
            self.baseTableView.reloadData()
            })
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        DLog("centralManager didUpdateValueForDescriptor: \(descriptor.uuid.uuidString), characteristic: \(descriptor.characteristic.uuid.uuidString)")
        valuesRead += 1
        
        DispatchQueue.main.async(execute: { [unowned self] in
            self.updateDiscoveringStatus()
            self.baseTableView.reloadData()
            })
    }
}
