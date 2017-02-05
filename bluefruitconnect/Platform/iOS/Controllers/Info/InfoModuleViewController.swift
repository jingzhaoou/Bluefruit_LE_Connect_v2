//
//  InfoViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 05/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class InfoModuleViewController: ModuleViewController {
    // Config
    fileprivate static let kReadForbiddenCCCD = false     // Added to avoid generating a didModifyServices callback when reading Uart/DFU CCCD (bug??)
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var waitView: UIActivityIndicatorView!
    
    // Delegates
    var onServicesDiscovered: (() -> ())?
//    var onInfoScanFinished: (() ->())?
    
    // Data
    fileprivate let refreshControl = UIRefreshControl()
    fileprivate var blePeripheral: BlePeripheral?
    fileprivate var services: [CBService]?
    fileprivate var itemDisplayMode = [String : DisplayMode]()
    
    fileprivate var shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled
    
    fileprivate var isDiscoveringServices = false
    fileprivate var elementsToDiscover = 0
    fileprivate var elementsDiscovered = 0
    fileprivate var valuesToRead = 0
    fileprivate var valuesRead = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Peripheral should be connected
        blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        guard blePeripheral != nil else {
            DLog("Error: Info: blePeripheral is nil")
            return
        }

        // Setup table
       // baseTableView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0)      // extend below navigation inset fix
        baseTableView.estimatedRowHeight = 60
        baseTableView.rowHeight = UITableViewAutomaticDimension

        // Setup table refresh
        /*
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubviewToBack(refreshControl)
        */
        
        // Discover services
        shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled
        services = nil
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if services == nil && !isDiscoveringServices {        // only the first time
            discoverServices()
        }
        
        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral!.name != nil ? blePeripheral!.name! : LocalizationManager.sharedInstance.localizedString("peripherallist_unnamed")
        
        let title = String(format: localizationManager.localizedString("info_navigation_title_format"), arguments: [name])
        //tabBarController?.navigationItem.title = title
        navigationController?.navigationItem.title = title
        
        // Refresh data
        baseTableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func discoverServices() {
        guard isDiscoveringServices == false else {
            DLog("warning: call to discoverServices while services discovery in process")
            return;
        }
        
        isDiscoveringServices = true
        elementsToDiscover = 0
        elementsDiscovered = 0
        valuesToRead = 0
        valuesRead = 0
        
        services = nil
        showWait(true)
        BleManager.sharedInstance.discover(blePeripheral!, serviceUUIDs: nil)
    }
    
    func showWait(_ show: Bool) {
        baseTableView.isHidden = show
        waitView.isHidden = !show
    }
    
    // MARK: - Actions
    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("info_help_text"), title: localizationManager.localizedString("info_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        present(helpNavigationController, animated: true, completion: nil)
    }
    
    // MARK - Actions
    func onTableRefresh(_ sender: AnyObject) {
        refreshControl.endRefreshing()
        discoverServices()
//        baseTableView.reloadData()
//        baseTableView.layoutIfNeeded()
        
    }
    
    @IBAction func onClickRefresh(_ sender: AnyObject) {
        discoverServices()
    }
    
}

extension InfoModuleViewController: UITableViewDataSource {
    enum DisplayMode : Int {
        case auto = 0
        case text = 1
        case hex = 2
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Services
        if let services = services {
            return services.count
        }
        else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let service = services![section]
        
        if let characteristics = service.characteristics {
            let numCharacteristics = characteristics.count

            var numDescriptors = 0
            for characteristic in characteristics {
                numDescriptors += characteristic.descriptors?.count ?? 0
            }
            
            //DLog("section:\(section) - numCharacteristics: \(numCharacteristics), numDescriptors:\(numDescriptors), service: \(service.UUID.UUIDString)")
            return numCharacteristics + numDescriptors
        }
        else {
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let service = services?[section] else {
            DLog("warning: titleForHeaderInSection service is nil")
            return nil
        }
        
        var identifier = service.uuid.uuidString
        if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
            identifier = name
        }

        return identifier
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    fileprivate func itemForIndexPath(_ indexPath: IndexPath) -> (Int, CBAttribute?, Bool) {
        let service = services![indexPath.section]
        
        // The same table view section is used for characteristics and descriptors. So first calculate if the current indexPath.row is for a characteristic or descriptor
        var currentItem: CBAttribute?
        var currentCharacteristicIndex = 0
        var currentRow = 0
        var isDescriptor = false
        
//        DLog("section:\(indexPath.section) - service: \(service.UUID.UUIDString)")
        while currentRow <= indexPath.row && currentCharacteristicIndex < service.characteristics!.count && service.characteristics != nil {
            let characteristic = service.characteristics![currentCharacteristicIndex]
            
            if currentRow == indexPath.row {
                currentItem = characteristic
                currentRow += 1     // same as break
            }
            else {
                currentRow += 1     // + 1 characteristic
                
                let numDescriptors = characteristic.descriptors?.count ?? 0
                if numDescriptors > 0 {
                    let remaining = indexPath.row-currentRow
                    if remaining < numDescriptors {
                        currentItem = characteristic.descriptors![remaining]
                        isDescriptor = true
                    }
                    currentRow += numDescriptors
                }
            }
            
            if currentItem == nil {
                currentCharacteristicIndex += 1
            }
        }
        
        if currentItem == nil {
            DLog("Error populating tableview")
        }
        
        return (currentCharacteristicIndex, currentItem, isDescriptor)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let service = services?[indexPath.section], service.characteristics != nil else {
            DLog("warning: cellForRowAtIndexPath characteristics is nil")
            return tableView.dequeueReusableCell(withIdentifier: "CharacteristicCell", for:indexPath)
        }
        
        let (currentCharacteristicIndex, currentItemOptional, isDescriptor) = itemForIndexPath(indexPath)
        
        guard let currentItem = currentItemOptional else  {
            DLog("warning: current item is nil")
            return tableView.dequeueReusableCell(withIdentifier: "CharacteristicCell", for:indexPath)
            
        }
        
        //DLog("secrow: \(indexPath.section)/\(indexPath.row): ci: \(currentCharacteristicIndex) isD: \(isDescriptor))")
        
        // Intanciate cell
        let reuseIdentifier = isDescriptor ? "DescriptorCell":"CharacteristicCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for:indexPath)

        
        var identifier = ""
        var value = " "
        var valueData: Data?
        if let characteristic = service.characteristics?[currentCharacteristicIndex] {
            
            identifier = currentItem.uuid.uuidString
            
            let displayModeIdentifier = "\(currentCharacteristicIndex)_\(identifier)"       // Descriptors in different characteristics could have the same CBUUID
            var currentDisplayMode = DisplayMode.auto
            if let displayMode = itemDisplayMode[displayModeIdentifier] {
                currentDisplayMode = displayMode
            }
            else {
                itemDisplayMode[displayModeIdentifier] = .auto
            }
            
            if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
                identifier = name
            }
            
            if isDescriptor {
                let descriptor = currentItem as! CBDescriptor
                valueData = InfoModuleManager.parseDescriptorValue(descriptor)
            }
            else {
                valueData = characteristic.value
            }
            
            if valueData != nil {
                switch currentDisplayMode {
                case .auto:
                    if let characteristicString = NSString(data: valueData!, encoding: String.Encoding.utf8.rawValue) as String? {
                        if isStringPrintable(characteristicString) {
                            value = characteristicString
                        }
                        else {      // print as hex
                            value = hexString(valueData!)
                        }
                    }
                case .text:
                    if let text = NSString(data:valueData!, encoding: String.Encoding.utf8.rawValue) as? String {
                        value = text
                    }
                case .hex:
                    value = hexString(valueData!)
                }
            }
        }
        
        let characteristicCell = cell as! InfoCharacteristicTableViewCell
        characteristicCell.titleLabel.text = identifier
        characteristicCell.subtitleLabel.text = valueData != nil ? value : LocalizationManager.sharedInstance.localizedString(isDescriptor ? "info_type_descriptor":"info_type_characteristic")
        characteristicCell.subtitleLabel.textColor = valueData != nil ? UIColor.black : UIColor.lightGray
        
        return cell
    }
    
    fileprivate func isStringPrintable(_ text: String) -> Bool {
        //NSCharacterSet
        //let printableCharacterSet:NSCharacterSet = NSCharacterSet(charactersInString: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLKMNOPQRSTUVWXYZ0123456789")
        
        let printableCharacterSet = CharacterSet.alphanumerics
        let isPrintable  = text.rangeOfCharacter(from: printableCharacterSet) != nil
        return isPrintable
    }
}

extension InfoModuleViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard let service = services?[indexPath.section], service.characteristics != nil else {
            DLog("warning: didSelectRowAtIndexPath characteristics is nil")
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        let (currentCharacteristicIndex, currentItemOptional, isDescriptor) = itemForIndexPath(indexPath)
        
        guard let currentItem = currentItemOptional else  {
            DLog("warning: current item is nil")
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        if let characteristic = service.characteristics?[currentCharacteristicIndex] {
            
            let identifier = currentItem.uuid.uuidString
            let displayModeIdentifier = "\(currentCharacteristicIndex)_\(identifier)"       // Descriptors in different characteristics could have the same CBUUID
            if let displayMode =  itemDisplayMode[displayModeIdentifier] {
                switch displayMode {
                case .text:
                    itemDisplayMode[displayModeIdentifier] = .hex
                case .hex:
                    itemDisplayMode[displayModeIdentifier] = .text
                default:
                    
                    // Check if is printable
                    var isPrintable = false
                    var valueData: Data?
                    if isDescriptor {
                        let descriptor = currentItem as! CBDescriptor
                        valueData = InfoModuleManager.parseDescriptorValue(descriptor)
                    }
                    else {
                        valueData = characteristic.value
                    }
                    
                    if let value = valueData {
                        if let characteristicString = NSString(data:value, encoding: String.Encoding.utf8.rawValue) as String? {
                            isPrintable = isStringPrintable(characteristicString)
                        }
                    }
                    itemDisplayMode[displayModeIdentifier] = isPrintable ? .hex: .text
                }
            }
            
            tableView.reloadData()
            //tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - CBPeripheralDelegate
extension InfoModuleViewController : CBPeripheralDelegate {
    
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        DLog("centralManager peripheralDidUpdateName: \(peripheral.name != nil ? peripheral.name! : "")")
        /*
        dispatch_async(dispatch_get_main_queue(),{ [weak self] in
            self?.discoverServices()
            })
 */
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
                        blePeripheral?.peripheral.discoverCharacteristics(nil, for: service)
                    }
                }
            }
                /*
            else {
                onInfoScanFinished?()
            }*/
            
            // Update UI
            DispatchQueue.main.async(execute: { [unowned self] in
 
                //self.updateDiscoveringStatusLabel()
                self.baseTableView?.reloadData()
                self.showWait(false)
                self.onServicesDiscovered?()
                })
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        //DLog("centralManager didDiscoverCharacteristicsForService: \(service.UUID.UUIDString)")
        
        elementsDiscovered += 1
        
        if let characteristics = service.characteristics {

            for characteristic in characteristics {
                if (characteristic.properties.rawValue & CBCharacteristicProperties.read.rawValue != 0) {
                    valuesToRead += 1
                    peripheral.readValue(for: characteristic)
                }
                
                //elementsToDiscover += 1       // Dont add descriptors to elementsToDiscover because the number of descriptors found is unknown
                blePeripheral?.peripheral.discoverDescriptors(for: characteristic)
            }
        }
        
        DispatchQueue.main.async(execute: { [unowned self] in
            self.baseTableView?.reloadData()
            })
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        //DLog("centralManager didDiscoverDescriptorsForCharacteristic: \(characteristic.UUID.UUIDString)")
        //elementsDiscovered += 1
        
        if let descriptors = characteristic.descriptors {
            for descriptor in descriptors {
                
                let isAForbiddenCCCD = descriptor.uuid.uuidString.caseInsensitiveCompare("2902") == .orderedSame && (characteristic.uuid.uuidString.caseInsensitiveCompare(UartManager.RxCharacteristicUUID) == .orderedSame || characteristic.uuid.uuidString.caseInsensitiveCompare(dfuControlPointCharacteristicUUIDString) == .orderedSame)
                if InfoModuleViewController.kReadForbiddenCCCD || !isAForbiddenCCCD {
                    
                    valuesToRead += 1
                    peripheral.readValue(for: descriptor)
                }
            }
        }
        
        if (self.elementsDiscovered == self.elementsToDiscover) {
            DispatchQueue.main.async(execute: { [unowned self] in
                self.baseTableView?.reloadData()
                })
        }
        
        /*
        if (self.valuesRead == self.valuesToRead) {
            dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.onInfoScanFinished?()
                })
        }
 */
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //DLog("centralManager didUpdateValueForCharacteristic: \(characteristic.UUID.UUIDString)")
        
        valuesRead += 1
        
        if (self.elementsDiscovered >= self.elementsToDiscover) {
            DispatchQueue.main.async(execute: { [unowned self] in
                //self.updateDiscoveringStatusLabel()
                self.baseTableView?.reloadData()
                })
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        //DLog("centralManager didUpdateValueForDescriptor: \(descriptor.UUID.UUIDString)")
        valuesRead += 1
        
        DLog("didUpdateValueForDescriptor: \(descriptor.uuid.uuidString) characteristic: \(descriptor.characteristic.uuid.uuidString)")
        
//        DLog("disco \(self.elementsDiscovered)/\(self.elementsToDiscover)")
        if (self.elementsDiscovered >= self.elementsToDiscover) {
            DispatchQueue.main.async(execute: { [unowned self] in
                //self.updateDiscoveringStatusLabel()
                self.baseTableView?.reloadData()
                })
        }
    }
}
