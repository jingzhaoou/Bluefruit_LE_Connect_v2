//
//  ControllerModuleViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ControllerModuleViewController: ModuleViewController {

    // Constants
    static fileprivate let kPollInterval = 0.25
    
    static fileprivate let kSensorTitleKeys : [String] = ["controller_sensor_quaternion", "controller_sensor_accelerometer", "controller_sensor_gyro", "controller_sensor_magnetometer", "controller_sensor_location"]
    static fileprivate let kModuleTitleKeys : [String] = ["controller_module_pad", "controller_module_colorpicker"]
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var uartWaitingLabel: UILabel!

    // Data
    fileprivate let controllerData = ControllerModuleManager()
    fileprivate var contentItems = [Int]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Init
        controllerData.delegate = self

        // Setup table
        baseTableView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0)      // extend below navigation inset fix
        updateUI()
        
        //
        updateContentItemsFromSensorsEnabled()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if isMovingToParentViewController {       // To keep streaming data when pushing a child view
            controllerData.start(ControllerModuleViewController.kPollInterval) { [unowned self] in
                self.baseTableView.reloadData()
            }
            
            // Watch
            WatchSessionManager.sharedInstance.updateApplicationContext(.Controller)
            
            DLog("register DidReceiveWatchCommand observer")
            let notificationCenter =  NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(watchCommand(_:)), name: NSNotification.Name(rawValue: WatchSessionManager.Notifications.DidReceiveWatchCommand.rawValue), object: nil)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if isMovingFromParentViewController {     // To keep streaming data when pushing a child view
            controllerData.stop()
            
            // Watch
            WatchSessionManager.sharedInstance.updateApplicationContext(.Connected)
            
            DLog("remove DidReceiveWatchCommand observer")
            let notificationCenter =  NotificationCenter.default
            notificationCenter.removeObserver(self, name:
            NSNotification.Name(rawValue: WatchSessionManager.Notifications.DidReceiveWatchCommand.rawValue), object: nil)
        }
    }
    
    deinit {
        DLog("deinit")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    fileprivate func updateUI() {
        // Setup UI
        let isUartReady = UartManager.sharedInstance.isReady()
        uartWaitingLabel.isHidden = isUartReady
        baseTableView.isHidden = !isUartReady
    }
    
    fileprivate let kDetailItemOffset = 100
    fileprivate func updateContentItemsFromSensorsEnabled() {
        var items = [Int]()
        var i = 0
        for j in 0..<ControllerModuleManager.numSensors {
            let isSensorEnabled = controllerData.isSensorEnabled(j)
            items.append(i)
            if isSensorEnabled {
                items.append(i+kDetailItemOffset)
            }
            i += 1
        }
        
        contentItems = items
    }
    
    // MARK: Notifications
    func watchCommand(_ notification: Notification) {
        if let message = notification.userInfo, let command = message["command"] as? String {
            DLog("watchCommand notification: \(command)")
            switch command {
            case "controlPad":
                if let tag = (message["tag"] as? Int) {
                    sendTouchEvent(tag, isPressed: true)
                    sendTouchEvent(tag, isPressed: false)
                }
                
            case "color":
                if  let colorUInt = message["color"] as? UInt, let color = colorFromHexUInt(colorUInt) {
                    sendColor(color)
                }
                
            default:
                DLog("watchCommand with unknown command: \(command)")
                break

            }
        }
    }

    // MARK: - Actions
    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("controller_help_text"), title: localizationManager.localizedString("controller_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        present(helpNavigationController, animated: true, completion: nil)
    }
    
    
     // MARK: - Send Data
    func sendColor(_ color: UIColor) {
        let brightness: CGFloat = 1
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        red = red*brightness
        green = green*brightness
        blue = blue*brightness
        
        let selectedColorComponents = [UInt8(255.0 * Float(red)), UInt8(255.0 * Float(green)), UInt8(255.0 * Float(blue))]
        
        sendColorComponents(selectedColorComponents)
    }
    
    func sendColorComponents(_ selectedColorComponents: [UInt8]) {
        let data = NSMutableData()
        let prefixData = ControllerColorWheelViewController.prefix.data(using: String.Encoding.utf8)!
        data.append(prefixData)
        for var component in selectedColorComponents {
            data.append(&component, length: MemoryLayout<UInt8>.size)
        }
        
        UartManager.sharedInstance.sendDataWithCrc(data as Data)
    }
    
    func sendTouchEvent(_ tag: Int, isPressed: Bool) {
        let message = "!B\(tag)\(isPressed ? "1" : "0")"
        if let data = message.data(using: String.Encoding.utf8) {
            UartManager.sharedInstance.sendDataWithCrc(data)
        }
    }
}

// MARK: - ControllerColorWheelViewControllerDelegate
extension ControllerModuleViewController : ControllerColorWheelViewControllerDelegate {
    func onSendColorComponents(_ colorComponents: [UInt8]) {
        sendColorComponents(colorComponents)
    }
}

// MARK: - ControllerPadViewControllerDelegate
extension ControllerModuleViewController : ControllerPadViewControllerDelegate {
    func onSendControllerPadButtonStatus(_ tag: Int, isPressed: Bool) {
        sendTouchEvent(tag, isPressed: isPressed)
    }
}

// MARK: - UITableViewDataSource
extension ControllerModuleViewController : UITableViewDataSource {
    
    enum ControllerSection : Int  {
        case sensorData = 0
        case module = 1
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch ControllerSection(rawValue: section)! {
        case .sensorData:
            //let enabledCount = sensorsEnabled.filter{ $0 }.count
            //return ControllerModuleViewController.kSensorTitleKeys.count + enabledCount
            return contentItems.count
        case .module:
            return ControllerModuleViewController.kModuleTitleKeys.count
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var localizationKey: String!
        
        switch ControllerSection(rawValue: section)! {
        case .sensorData:
            localizationKey = "controller_sensor_title"
        case .module:
            localizationKey = "controller_module_title"
        }
        
        return LocalizationManager.sharedInstance.localizedString(localizationKey)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let localizationManager = LocalizationManager.sharedInstance
        var cell: UITableViewCell!
        switch ControllerSection(rawValue: indexPath.section)! {
            
        case .sensorData:
            let item = contentItems[indexPath.row]
            let isDetailCell = item>=kDetailItemOffset
            
            if isDetailCell {
                let sensorIndex = item - kDetailItemOffset
                let reuseIdentifier = "ComponentsCell"
                let componentsCell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ControllerComponentsTableViewCell
             
                let componentNameKeys : [String]
                if sensorIndex == ControllerModuleManager.ControllerType.location.rawValue {
                    componentNameKeys = ["lat", "long", "alt"]
                }
                else {
                    componentNameKeys = ["x", "y", "z", "w"]
                }
                if let sensorData = controllerData.getSensorData(sensorIndex) {
                    var i=0
                    for subview in componentsCell.componentsStackView.subviews {
                        let hasComponent = i<sensorData.count
                        subview.isHidden = !hasComponent
                        if let label = subview as? UILabel, hasComponent {
                            let attributedText = NSMutableAttributedString(string: "\(componentNameKeys[i]): \(sensorData[i])")
                            let titleLength = componentNameKeys[i].lengthOfBytes(using: String.Encoding.utf8)
                            attributedText.addAttribute(NSFontAttributeName, value: UIFont.systemFont(ofSize: 12, weight: UIFontWeightMedium), range: NSMakeRange(0, titleLength))
                            label.attributedText = attributedText
                        }
                   
                        i += 1
                    }
                }
                else {
                    for subview in componentsCell.componentsStackView.subviews {
                        subview.isHidden = true
                    }
                }
                
                cell = componentsCell
            }
            else {
                let reuseIdentifier = "SensorCell"
                let sensorCell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ControllerSensorTableViewCell
                sensorCell.titleLabel!.text = localizationManager.localizedString( ControllerModuleViewController.kSensorTitleKeys[item])
                
                sensorCell.enableSwitch.isOn = controllerData.isSensorEnabled(item)
                sensorCell.onSensorEnabled = { [unowned self] (enabled) in
                    
                    if self.controllerData.isSensorEnabled[item] != enabled {       // if changed
                        let errorMessage = self.controllerData.setSensorEnabled(enabled, index:item)

                        if let errorMessage = errorMessage {
                            let alertController = UIAlertController(title: localizationManager.localizedString("dialog_error"), message: errorMessage, preferredStyle: .alert)
                            
                            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler:nil)
                            alertController.addAction(okAction)
                            self.present(alertController, animated: true, completion: nil)
                        }
                        
                        self.updateContentItemsFromSensorsEnabled()
                        
                        /* Not used because the animation for the section title looks weird. Used a reloadData instead
                        if let currentRow = self.contentItems.indexOf(item) {
                            let detailIndexPath = NSIndexPath(forRow: currentRow+1, inSection: indexPath.section)
                            if enabled {
                                tableView.insertRowsAtIndexPaths([detailIndexPath], withRowAnimation: .Top)
                            }
                            else {
                                tableView.deleteRowsAtIndexPaths([detailIndexPath], withRowAnimation: .Bottom)
                            }
                        }
                        */
                        
                    }
 
                    self.baseTableView.reloadData()
                }
                cell = sensorCell
            }
            
        case .module:
            let reuseIdentifier = "ModuleCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
            }
            cell.accessoryType = .disclosureIndicator
            cell.textLabel!.text = localizationManager.localizedString(ControllerModuleViewController.kModuleTitleKeys[indexPath.row])
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch ControllerSection(rawValue: indexPath.section)! {
        case .sensorData:
            let item = contentItems[indexPath.row]
            let isDetailCell = item>=kDetailItemOffset
            return isDetailCell ? 120: 44
        default:
            return 44
        }
    }
}

// MARK:  UITableViewDelegate
extension ControllerModuleViewController : UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch ControllerSection(rawValue: indexPath.section)! {
        case .module:
            if indexPath.row == 0 {
                 let viewController = storyboard!.instantiateViewController(withIdentifier: "ControllerPadViewController") as! ControllerPadViewController
                viewController.delegate = self
                navigationController?.show(viewController, sender: self)
            }
            else {
                let viewController = storyboard!.instantiateViewController(withIdentifier: "ControllerColorWheelViewController") as! ControllerColorWheelViewController
                viewController.delegate = self
                navigationController?.show(viewController, sender: self)
                
            }

        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - ControllerModuleManagerDelegate
extension ControllerModuleViewController: ControllerModuleManagerDelegate {
    func onControllerUartIsReady() {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.updateUI()
            self.baseTableView.reloadData()
            });
    }
}
