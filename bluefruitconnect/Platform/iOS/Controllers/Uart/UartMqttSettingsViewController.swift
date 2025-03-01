//
//  UartMqttSettingsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 07/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class UartMqttSettingsViewController: UIViewController {
    
    // Constants
    static let kDefaultHeaderCellHeight : CGFloat = 50;
    
    // Types
    /* private */ enum SettingsSections : Int {
        case Status = 0
        case Server = 1
        case Publish = 2
        case Subscribe = 3
        case Advanced = 4
    }
    
    /* private */ enum PickerViewType {
        case Qos
        case Action
    }
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!
    /* private */ var openCellIndexPath : NSIndexPath?
    /* private */ var pickerViewType = PickerViewType.Qos
    
    // Data
    private var previousSubscriptionTopic : String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = LocalizationManager.sharedInstance.localizedString("uart_mqtt_settings_title")
     
       // view.backgroundColor = StyleConfig.backgroundColor
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        previousSubscriptionTopic = MqttSettings.sharedInstance.subscribeTopic
        MqttManager.sharedInstance.delegate = self
        baseTableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func headerTitleForSection(section: Int) -> String? {
        var key : String?
        switch SettingsSections(rawValue: section)! {
        case .Status: key = "uart_mqtt_settings_group_status" //  nil
        case .Server: key = "uart_mqtt_settings_group_server"
        case .Publish: key = "uart_mqtt_settings_group_publish"
        case .Subscribe: key = "uart_mqtt_settings_group_subscribe"
        case .Advanced: key = "uart_mqtt_settings_group_advanced"
        }
        
        return (key==nil ? nil : LocalizationManager.sharedInstance.localizedString(key!).uppercased())
    }
    
    func subscriptionTopicChanged(newTopic: String?, qos: MqttManager.MqttQos) {
        DLog("subscription changed from: \(previousSubscriptionTopic != nil ? previousSubscriptionTopic!:"") to: \(newTopic != nil ? newTopic!:"")");
        
        let mqttManager = MqttManager.sharedInstance
        if (previousSubscriptionTopic != nil) {
            mqttManager.unsubscribe(previousSubscriptionTopic!)
        }
        if (newTopic != nil) {
            mqttManager.subscribe(newTopic!, qos: qos)
        }
        previousSubscriptionTopic = newTopic
    }
}

// MARK: UITableViewDataSource
extension UartMqttSettingsViewController: UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return SettingsSections.Advanced.rawValue + 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numberOfRows = 0
        switch SettingsSections(rawValue: section)! {
        case .Status: numberOfRows = 1
        case .Server: numberOfRows = 2
        case .Publish: numberOfRows = 2
        case .Subscribe: numberOfRows = 2
        case .Advanced: numberOfRows = 2
        }
        
        if let openCellIndexPath = openCellIndexPath {
            if openCellIndexPath.section == section {
                numberOfRows += 1
            }
        }
        return numberOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = SettingsSections(rawValue: indexPath.section)!
        let cell : UITableViewCell
        
        
        if indexPath == openCellIndexPath as! IndexPath {
            let pickerCell = tableView.dequeueReusableCell(withIdentifier: "PickerCell", for: indexPath) as! MqttSettingPickerCell
            pickerCell.pickerView.tag = indexPath.section * 100 + indexPath.row-1
            pickerCell.pickerView.dataSource = self
            pickerCell.pickerView.delegate = self
            
            pickerCell.backgroundColor = UIColor(hex: 0xe2e1e0)
            cell = pickerCell
        }
        else if section == .Status {
            let statusCell = tableView.dequeueReusableCell(withIdentifier: "StatusCell", for: indexPath) as! MqttSettingsStatusCell
            
            let status = MqttManager.sharedInstance.status
            let showWait = status == .connecting || status == .disconnecting
            if (showWait) {
                statusCell.waitView.startAnimating()
            }else {
                statusCell.waitView.stopAnimating()
            }
            statusCell.actionButton.isHidden = showWait
            statusCell.statusLabel.text = titleForMqttManagerStatus(status: status)
            
            UIView.performWithoutAnimation({ () -> Void in      // Change title disabling animations (if enabled the user can see the old title for a moment)
                statusCell.actionButton.setTitle(status == .connected ?"Disconnect":"Connect", for: UIControlState.normal)
                statusCell.layoutIfNeeded()
            })
            
            statusCell.onClickAction = {  [unowned self] in
                // End editing
                self.view.endEditing(true)
                
                // Connect / Disconnect
                let mqttManager = MqttManager.sharedInstance
                let status = mqttManager.status
                if (status == .disconnected || status == .none || status == .error) {
                    mqttManager.connectFromSavedSettings()
                } else {
                    mqttManager.disconnect()
                    MqttSettings.sharedInstance.isConnected = false
                }
                
                self.baseTableView?.reloadData()
            }
            
            statusCell.backgroundColor = UIColor.clear
            cell = statusCell
        }
        else {
            let mqttSettings = MqttSettings.sharedInstance
            let editValueCell : MqttSettingsValueAndSelector
            let row = indexPath.row
            
            switch section {
            case .Server:
                editValueCell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath) as! MqttSettingsValueAndSelector
                editValueCell.reset()
                
                let labels = ["Address:", "Port:"]
                editValueCell.nameLabel.text = labels[row]
                let valueTextField = editValueCell.valueTextField!      // valueTextField should exist on this cell
                if (row == 0) {
                    valueTextField.text = mqttSettings.serverAddress
                }
                else if (row == 1) {
                    valueTextField.placeholder = "\(MqttSettings.defaultServerPort)"
                    if (mqttSettings.serverPort != MqttSettings.defaultServerPort) {
                        valueTextField.text = "\(mqttSettings.serverPort)"
                    }
                    valueTextField.keyboardType = UIKeyboardType.numberPad;
                }
                
            case .Publish:
                editValueCell = tableView.dequeueReusableCell(withIdentifier: "ValueAndSelectorCell", for: indexPath) as! MqttSettingsValueAndSelector
                editValueCell.reset()
                
                let labels = ["Uart RX:", "Uart TX:"]
                editValueCell.nameLabel.text = labels[row]
                
                editValueCell.valueTextField!.text = mqttSettings.getPublishTopic(row)

                let typeButton = editValueCell.typeButton!
                typeButton.tag = tagFromIndexPath(indexPath: indexPath as NSIndexPath, scale:100)
                typeButton.setTitle(titleForQos(qos: mqttSettings.getPublishQos(row)), for: .normal)
                typeButton.addTarget(self, action: #selector(UartMqttSettingsViewController.onClickTypeButton(sender:)), for: .touchUpInside)
                
            case .Subscribe:
                editValueCell = tableView.dequeueReusableCell(withIdentifier: row==0 ? "ValueAndSelectorCell":"SelectorCell", for: indexPath) as! MqttSettingsValueAndSelector
                editValueCell.reset()
                
                let labels = ["Topic:", "Action:"]
                editValueCell.nameLabel.text = labels[row]
                
                let typeButton = editValueCell.typeButton!
                typeButton.tag = tagFromIndexPath(indexPath: indexPath as NSIndexPath, scale:100)
                typeButton.addTarget(self, action: #selector(UartMqttSettingsViewController.onClickTypeButton(sender:)), for: .touchUpInside)
                if (row == 0) {
                    editValueCell.valueTextField!.text = mqttSettings.subscribeTopic
                    typeButton.setTitle(titleForQos(qos: mqttSettings.subscribeQos), for: .normal)
                }
                else if (row == 1) {
                    typeButton.setTitle(titleForSubscribeBehaviour(behaviour: mqttSettings.subscribeBehaviour), for: .normal)
                }
                
            case .Advanced:
                editValueCell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath) as! MqttSettingsValueAndSelector
                editValueCell.reset()
                
                let labels = ["Username:", "Password:"]
                editValueCell.nameLabel.text = labels[row]
                
                let valueTextField = editValueCell.valueTextField!
                if (row == 0) {
                    valueTextField.text = mqttSettings.username
                }
                else if (row == 1) {
                    valueTextField.text = mqttSettings.password
                }
                
            default:
                editValueCell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath) as! MqttSettingsValueAndSelector
                editValueCell.reset()
            }
            
            if let valueTextField = editValueCell.valueTextField {
                valueTextField.returnKeyType = UIReturnKeyType.next
                valueTextField.delegate = self;
                valueTextField.tag = tagFromIndexPath(indexPath: indexPath as NSIndexPath, scale:10)
            }
            
            editValueCell.backgroundColor = UIColor(hex: 0xe2e1e0)
            cell = editValueCell
        }
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return indexPath == openCellIndexPath ? 100 : 44
    }
    
    private func tagFromIndexPath(indexPath : NSIndexPath, scale : Int) -> Int {
        // To help identify each textfield a tag is added with this format: ab (a is the section, b is the row)
        return indexPath.section * scale + indexPath.row
    }
    
    /* private */ func indexPathFromTag(tag: Int, scale: Int) -> NSIndexPath {
        // To help identify each textfield a tag is added with this format: 12 (1 is the section, 2 is the row)
        return NSIndexPath(row: tag % scale, section: tag / scale)
    }
    
    func onClickTypeButton(sender : UIButton) {
        let selectedIndexPath = indexPathFromTag(tag: sender.tag, scale:100)
        let isAction = selectedIndexPath.section ==  SettingsSections.Subscribe.rawValue && selectedIndexPath.row == 1
        pickerViewType = isAction ? PickerViewType.Action : PickerViewType.Qos
        
        displayInlineDatePickerForRowAtIndexPath(indexPath: selectedIndexPath)
    }
    
    private func displayInlineDatePickerForRowAtIndexPath(indexPath : NSIndexPath) {
        // display the date picker inline with the table content
        baseTableView.beginUpdates()
        
        var before = false   // indicates if the date picker is below "indexPath", help us determine which row to reveal
        var sameCellClicked = false
        if let openCellIndexPath = openCellIndexPath {
            before = openCellIndexPath.section <= indexPath.section && openCellIndexPath.row < indexPath.row
            
            sameCellClicked = openCellIndexPath.section == indexPath.section && openCellIndexPath.row - 1 == indexPath.row
            
            // remove any date picker cell if it exists
            baseTableView.deleteRows(at: [openCellIndexPath as IndexPath], with: .fade)
            self.openCellIndexPath = nil;
        }
        
        if !sameCellClicked {
            // hide the old date picker and display the new one
            let rowToReveal = before ? indexPath.row - 1 : indexPath.row
            let indexPathToReveal = NSIndexPath(row:rowToReveal, section:indexPath.section)
            
            toggleDatePickerForSelectedIndexPath(indexPath: indexPathToReveal)
            self.openCellIndexPath = NSIndexPath(row:indexPathToReveal.row + 1, section:indexPathToReveal.section)
        }
        
        // always deselect the row containing the start or end date
        baseTableView.deselectRow(at: indexPath as IndexPath, animated:true)
        
        baseTableView.endUpdates()
        
        // inform our date picker of the current date to match the current cell
        //updateOpenCell()
    }
    
    func toggleDatePickerForSelectedIndexPath(indexPath : NSIndexPath) {
        
        baseTableView.beginUpdates()
        let indexPaths = [NSIndexPath(row:indexPath.row + 1, section:indexPath.section)]
        
        // check if 'indexPath' has an attached date picker below it
        if hasPickerForIndexPath(indexPath: indexPath) {
            // found a picker below it, so remove it
            baseTableView.deleteRows(at: indexPaths as [IndexPath], with:.fade)
        }
        else {
            // didn't find a picker below it, so we should insert it
            baseTableView.insertRows(at: indexPaths as [IndexPath], with:.fade)
        }
        
        baseTableView.endUpdates()
    }
    
    private func hasPickerForIndexPath(indexPath : NSIndexPath) -> Bool {
        var hasPicker = false
        
        if baseTableView.cellForRow(at: NSIndexPath(row: indexPath.row+1, section: indexPath.section) as IndexPath) is MqttSettingPickerCell {
            hasPicker = true
        }
        
        return hasPicker
    }
    
    private func titleForMqttManagerStatus(status : MqttManager.ConnectionStatus) -> String {
        let statusText : String
        switch status {
        case .connected: statusText = "Connected"
        case .connecting: statusText = "Connecting..."
        case .disconnecting: statusText = "Disconnecting..."
        case .error: statusText = "Error"
        default: statusText = "Disconnected"
        }
        return statusText
    }
    
    /* private */ func titleForSubscribeBehaviour(behaviour: MqttSettings.SubscribeBehaviour) -> String {
        switch behaviour {
        case .localOnly: return "Local Only"
        case .transmit: return "Transmit"
        }
    }
    
    /* private */ func titleForQos(qos: MqttManager.MqttQos) -> String {
        switch qos  {
        case .atLeastOnce : return "At Least Once"
        case .atMostOnce : return "At Most Once"
        case .exactlyOnce : return "Exactly Once"
        }
    }
}

// MARK: UITableViewDelegate
extension UartMqttSettingsViewController : UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerCell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell") as! MqttSettingsHeaderCell
        headerCell.backgroundColor = UIColor.clear
        headerCell.nameLabel.text = headerTitleForSection(section: section)
        let hasSwitch = section == SettingsSections.Publish.rawValue || section == SettingsSections.Subscribe.rawValue;
        headerCell.isOnSwitch.isHidden = !hasSwitch;
        if (hasSwitch) {
            let mqttSettings = MqttSettings.sharedInstance;
            if (section == SettingsSections.Publish.rawValue) {
                headerCell.isOnSwitch.isOn = mqttSettings.isPublishEnabled
                headerCell.isOnChanged = { isOn in
                    mqttSettings.isPublishEnabled = isOn;
                }
            }
            else if (section == SettingsSections.Subscribe.rawValue) {
                headerCell.isOnSwitch.isOn = mqttSettings.isSubscribeEnabled
                headerCell.isOnChanged = { [unowned self] isOn in
                    mqttSettings.isSubscribeEnabled = isOn;
                    self.subscriptionTopicChanged(newTopic: nil, qos: mqttSettings.subscribeQos)
                }
            }
        }
        
        return headerCell.contentView;
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if (headerTitleForSection(section: section) == nil) {
            UITableViewAutomaticDimension
            return 0.5;       // no title, so 0 height (hack: set to 0.5 because 0 height is not correctly displayed)
        }
        else {
            return UartMqttSettingsViewController.kDefaultHeaderCellHeight;
        }
    }
}

// MARK: UIPickerViewDataSource
extension UartMqttSettingsViewController: UIPickerViewDataSource {
    func numberOfComponents(in: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerViewType == .Action ? 2:3
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String?
    {
        switch(pickerViewType) {
        case .Qos:
            return titleForQos(qos: MqttManager.MqttQos(rawValue: row)!)
        case .Action:
            return titleForSubscribeBehaviour(behaviour: MqttSettings.SubscribeBehaviour(rawValue: row)!)
        }
    }
}

// MARK: UIPickerViewDelegate
extension UartMqttSettingsViewController: UIPickerViewDelegate {
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedIndexPath = indexPathFromTag(tag: pickerView.tag, scale:100)
        
        // Update settings with new values
        let section = SettingsSections(rawValue: selectedIndexPath.section)!
        let mqttSettings = MqttSettings.sharedInstance;
        
        switch section {
        case .Publish:
            mqttSettings.setPublishQos(selectedIndexPath.row, qos: MqttManager.MqttQos(rawValue: row)!)
            
        case .Subscribe:
            if (selectedIndexPath.row == 0) {     // Topic Qos
                let qos = MqttManager.MqttQos(rawValue: row)!
                mqttSettings.subscribeQos =  qos
                subscriptionTopicChanged(newTopic: mqttSettings.subscribeTopic, qos: qos)
            }
            else if (selectedIndexPath.row == 1) {    // Action
                mqttSettings.subscribeBehaviour = MqttSettings.SubscribeBehaviour(rawValue: row)!
            }
        default:
            break;
        }
        
        // Refresh cell
        baseTableView.reloadRows(at: [selectedIndexPath as IndexPath], with: .none)
    }
}

// MARK: - UITextFieldDelegate
extension UartMqttSettingsViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        
        // Go to next textField
        if (textField.returnKeyType == UIReturnKeyType.next) {
            let tag = textField.tag;
            var nextPathForTag = indexPathFromTag(tag: tag+1, scale:10)
            var nextView = baseTableView.cellForRow(at: nextPathForTag as IndexPath)?.viewWithTag(tag+1)
            if (nextView == nil) {
                let nexSectionTag = ((tag/10)+1)*10
                nextPathForTag = indexPathFromTag(tag: nexSectionTag, scale:10)
                nextView = baseTableView.cellForRow(at: nextPathForTag as IndexPath)?.viewWithTag(nexSectionTag)
            }
            if let next = nextView as? UITextField {
                next.becomeFirstResponder()
                
                // Scroll to show it
                baseTableView.scrollToRow(at: nextPathForTag as IndexPath, at: .middle, animated: true)
                
            }
            else {
                textField.resignFirstResponder()
            }
        }
    
        return true;
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        let indexPath = indexPathFromTag(tag: textField.tag, scale:10)
        let section = indexPath.section
        let row = indexPath.row
        let mqttSettings = MqttSettings.sharedInstance;
        
        // Update settings with new values
        switch(section) {
        case SettingsSections.Server.rawValue:
            if (row == 0) {         // Server Address
                mqttSettings.serverAddress = textField.text
            }
            else if (row == 1) {    // Server Port
                if let port = Int(textField.text!) {
                    mqttSettings.serverPort = port
                }
                else {
                    textField.text = nil;
                    mqttSettings.serverPort = MqttSettings.defaultServerPort
                }
            }
            
        case SettingsSections.Publish.rawValue:
            mqttSettings.setPublishTopic(row, topic: textField.text)
            
        case SettingsSections.Subscribe.rawValue:
            let topic = textField.text
            mqttSettings.subscribeTopic = topic
            subscriptionTopicChanged(newTopic: topic, qos: mqttSettings.subscribeQos)
            
        case SettingsSections.Advanced.rawValue:
            if (row == 0) {            // Username
                mqttSettings.username = textField.text;
            }
            else if (row == 1) {      // Password
                mqttSettings.password = textField.text;
            }
            
        default:
            break;
        }
    }
}

// MARK: - MqttManagerDelegate
extension UartMqttSettingsViewController: MqttManagerDelegate {
    func onMqttConnected() {
        // Update status
        DispatchQueue.main.async {
            self.baseTableView.reloadData()
        }
    }
    
    func onMqttDisconnected() {
        // Update status
        DispatchQueue.main.async {
            self.baseTableView.reloadData()
        }
    }
    
    func onMqttMessageReceived(_ message : String, topic: String) {
    }
    
    func onMqttError(_ message : String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title:"Error", message: message, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            
            // Update status
            self.baseTableView.reloadData()
        }
    }
}

