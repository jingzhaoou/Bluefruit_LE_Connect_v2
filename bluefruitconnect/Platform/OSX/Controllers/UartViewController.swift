//
//  UartViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class UartViewController: NSViewController {
    
    // UI Outlets
    @IBOutlet var baseTextView: NSTextView!
    @IBOutlet weak var baseTextVisibilityView: NSScrollView!
    @IBOutlet weak var baseTableView: NSTableView!
    @IBOutlet weak var baseTableVisibilityView: NSScrollView!
    
    @IBOutlet weak var hexModeSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var displayModeSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var mqttStatusButton: NSButton!
    
    @IBOutlet weak var inputTextField: NSTextField!
    @IBOutlet weak var echoButton: NSButton!
    @IBOutlet weak var eolButton: NSButton!
    
    @IBOutlet weak var sentBytesLabel: NSTextField!
    @IBOutlet weak var receivedBytesLabel: NSTextField!
    
    @IBOutlet var saveDialogCustomView: NSView!
    @IBOutlet weak var saveDialogPopupButton: NSPopUpButton!
    
    // Data
    fileprivate let uartData = UartModuleManager()
    
    // UI
    fileprivate static var dataFont = Font(name: "CourierNewPSMT", size: 13)!
    fileprivate var txColor = Preferences.uartSentDataColor
    fileprivate var rxColor = Preferences.uartReceveivedDataColor
    fileprivate let timestampDateFormatter = DateFormatter()
    fileprivate var tableCachedDataBuffer : [UartDataChunk]?
    fileprivate var tableModeDataMaxWidth : CGFloat = 0

    // Export
    fileprivate var exportFileDialog: NSSavePanel?

    // MARK:
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init Data
        uartData.delegate = self
        timestampDateFormatter.setLocalizedDateFormatFromTemplate("HH:mm:ss:SSSS")
        
        // Init UI
        hexModeSegmentedControl.selectedSegment = Preferences.uartIsInHexMode ? 1:0
        displayModeSegmentedControl.selectedSegment = Preferences.uartIsDisplayModeTimestamp ? 1:0
        
        echoButton.state = Preferences.uartIsEchoEnabled ? NSOnState:NSOffState
        eolButton.state = Preferences.uartIsAutomaticEolEnabled ? NSOnState:NSOffState
        
        // UI
        baseTableVisibilityView.scrollerStyle = NSScrollerStyle.legacy      // To avoid autohide behaviour
        reloadDataUI()
        
        // Mqtt init
        let mqttManager = MqttManager.sharedInstance
        if (MqttSettings.sharedInstance.isConnected) {
            mqttManager.delegate = uartData
            mqttManager.connectFromSavedSettings()
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        
        registerNotifications(true)
        mqttUpdateStatusUI()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        registerNotifications(false)
    }
    
    deinit {
        let mqttManager = MqttManager.sharedInstance
        mqttManager.disconnect()
    }
    
    
    // MARK: - Preferences
    func registerNotifications(_ register : Bool) {
        
        let notificationCenter =  NotificationCenter.default
        if (register) {
            notificationCenter.addObserver(self, selector: #selector(UartViewController.preferencesUpdated(_:)), name: NSNotification.Name(rawValue: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue), object: nil)
        }
        else {
            notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue), object: nil)
        }
    }
    
    func preferencesUpdated(_ notification : Notification) {
        txColor = Preferences.uartSentDataColor
        rxColor = Preferences.uartReceveivedDataColor
        reloadDataUI()
        
    }
    
    
    // MARK: - UI Updates
    func reloadDataUI() {
        let displayMode = Preferences.uartIsDisplayModeTimestamp ? UartModuleManager.DisplayMode.table : UartModuleManager.DisplayMode.text
        
        baseTableVisibilityView.isHidden = displayMode == .text
        baseTextVisibilityView.isHidden = displayMode == .table
        
        switch(displayMode) {
        case .text:
            if let textStorage = self.baseTextView.textStorage {
                
                let isScrollAtTheBottom = baseTextView.enclosingScrollView?.verticalScroller?.floatValue == 1

                textStorage.beginEditing()
                textStorage.replaceCharacters(in: NSMakeRange(0, textStorage.length), with: NSAttributedString())        // Clear text
                for dataChunk in uartData.dataBuffer {
                    addChunkToUIText(dataChunk)
                }
                textStorage .endEditing()
                if isScrollAtTheBottom {
                    baseTextView.scrollRangeToVisible(NSMakeRange(textStorage.length, 0))
                }
                
            }
            
        case .table:
            //let isScrollAtTheBottom = tableCachedDataBuffer == nil || tableCachedDataBuffer!.isEmpty  || baseTableView.enclosingScrollView?.verticalScroller?.floatValue == 1
            let isScrollAtTheBottom = tableCachedDataBuffer == nil || tableCachedDataBuffer!.isEmpty || NSLocationInRange(tableCachedDataBuffer!.count-1, baseTableView.rows(in: baseTableView.visibleRect))

            baseTableView.sizeLastColumnToFit()
            baseTableView.reloadData()
            if isScrollAtTheBottom {
                baseTableView.scrollToEndOfDocument(nil)
            }
        }
        
        updateBytesUI()
    }
    
    func updateBytesUI() {
        if let blePeripheral = uartData.blePeripheral {
            let localizationManager = LocalizationManager.sharedInstance
            sentBytesLabel.stringValue = String(format: localizationManager.localizedString("uart_sentbytes_format"), arguments: [blePeripheral.uartData.sentBytes])
            receivedBytesLabel.stringValue = String(format: localizationManager.localizedString("uart_recievedbytes_format"), arguments: [blePeripheral.uartData.receivedBytes])
        }
    }
    
    // MARK: - UI Actions
    @IBAction func onClickEcho(_ sender: NSButton) {
        Preferences.uartIsEchoEnabled = echoButton.state == NSOnState
        reloadDataUI()
    }
    
    @IBAction func onClickEol(_ sender: NSButton) {
        Preferences.uartIsAutomaticEolEnabled = eolButton.state == NSOnState
    }
    
    @IBAction func onChangeHexMode(_ sender: AnyObject) {
        Preferences.uartIsInHexMode = sender.selectedSegment == 1
        reloadDataUI()
    }
    
    @IBAction func onChangeDisplayMode(_ sender: NSSegmentedControl) {
        Preferences.uartIsDisplayModeTimestamp = sender.selectedSegment == 1
        reloadDataUI()
    }
    
    @IBAction func onClickClear(_ sender: NSButton) {
        uartData.clearData()
        tableModeDataMaxWidth = 0
        reloadDataUI()
    }
    
    @IBAction func onClickSend(_ sender: AnyObject) {
        let text = inputTextField.stringValue
        
        var newText = text
        // Eol
        if (Preferences.uartIsAutomaticEolEnabled)  {
            newText += "\n"
        }

        uartData.sendMessageToUart(newText)
        inputTextField.stringValue = ""
    }
    
    @IBAction func onClickExport(_ sender: AnyObject) {
        exportData()
    }
    
    @IBAction func onClickMqtt(_ sender: AnyObject) {
        
        let mqttManager = MqttManager.sharedInstance
        let status = mqttManager.status
        if status != .connected && status != .connecting {
            if let serverAddress = MqttSettings.sharedInstance.serverAddress, !serverAddress.isEmpty {
                // Server address is defined. Start connection
                mqttManager.delegate = uartData
                mqttManager.connectFromSavedSettings()
            }
            else {
                // Server address not defined
                let localizationManager = LocalizationManager.sharedInstance
                let alert = NSAlert()
                alert.messageText = localizationManager.localizedString("uart_mqtt_undefinedserver")
                alert.addButton(withTitle: localizationManager.localizedString("dialog_ok"))
                alert.addButton(withTitle: localizationManager.localizedString("uart_mqtt_editsettings"))
                alert.alertStyle = .warning
                alert.beginSheetModal(for: self.view.window!, completionHandler: { [unowned self] (returnCode) -> Void in
                    if returnCode == NSAlertSecondButtonReturn {
                        let preferencesViewController = self.storyboard?.instantiateController(withIdentifier: "PreferencesViewController") as! PreferencesViewController
                        self.presentViewControllerAsModalWindow(preferencesViewController)
                    }
                }) 
            }
        }
        else {
            mqttManager.disconnect()
        }
        
        mqttUpdateStatusUI()
    }
    
    // MARK: - Export
    fileprivate func exportData() {
        let localizationManager = LocalizationManager.sharedInstance
        
        // Check if data is empty
        guard uartData.dataBuffer.count > 0 else {
            let alert = NSAlert()
            alert.messageText = localizationManager.localizedString("uart_export_nodata")
            alert.addButton(withTitle: localizationManager.localizedString("dialog_ok"))
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
            return
        }
        
        // Show save dialog
        exportFileDialog = NSSavePanel()
        
        guard let exportFileDialog = exportFileDialog else {
            DLog("Error: Cannot create NSSavePanel")
            return
        }
        
        exportFileDialog.delegate = self
        exportFileDialog.message = localizationManager.localizedString("uart_export_save_message")
        exportFileDialog.prompt = localizationManager.localizedString("uart_export_save_prompt")
        exportFileDialog.canCreateDirectories = true
        exportFileDialog.accessoryView = saveDialogCustomView

        for exportFormat in UartModuleManager.kExportFormats {
            //let menuItem = NSMenuItem(title: exportFormat.rawValue, action: nil, keyEquivalent: "")
            //menuItem.representedObject = exportFormat
            //saveDialogPopupButton.menu?.addItem(menuItem)
            saveDialogPopupButton.addItem(withTitle: exportFormat.rawValue)
        }
        saveDialogPopupButton.menu?.delegate = self

        updateSaveFileName()

        guard let window = self.view.window else {
            DLog("Error: window not defined")
            return
        }
        
        exportFileDialog.beginSheetModal(for: window) {[unowned self] (result) -> Void in
            if result == NSFileHandlingPanelOKButton {
                if let url = exportFileDialog.url {
                    
                    // Save
                    let exportFormatSelected = UartModuleManager.kExportFormats[self.saveDialogPopupButton.indexOfSelectedItem]
                    
                    let dataBuffer = self.uartData.dataBuffer
                    switch(exportFormatSelected) {
                    case .txt:
                        let text = UartDataExport.dataAsText(dataBuffer)
                        self.exportData(text, url: url)
                    case .csv:
                        let text = UartDataExport.dataAsCsv(dataBuffer)
                        self.exportData(text, url: url)
                    case .json:
                        let text = UartDataExport.dataAsJson(dataBuffer)
                        self.exportData(text, url: url)
                    case .xml:
                        let text = UartDataExport.dataAsXml(dataBuffer)
                        self.exportData(text, url: url)
                    case .bin:
                        let data = UartDataExport.dataAsBinary(dataBuffer)
                        self.exportData(data, url: url)
                    }
                }
            }
        }
    }
    
    fileprivate func exportData(_ data: Data?, url: URL) {
        do {
            try data?.write(to: url, options: [.atomic])
        }
        catch let error {
            DLog("Error exporting file \(url.absoluteString): \(error)")
        }
    }
    
    fileprivate func exportData(_ text: String?, url: URL) {
        do {
            try text?.write(to: url, atomically: true, encoding: String.Encoding.utf8)
        }
        catch let error {
            DLog("Error exporting file \(url.absoluteString): \(error)")
        }
    }
    
    @IBAction func onExportFormatChanged(_ sender: AnyObject) {
        updateSaveFileName()
    }
    
    fileprivate func updateSaveFileName() {
        
        guard let exportFileDialog = exportFileDialog else {
            return
        }
        
        let isInHexMode = Preferences.uartIsInHexMode
        let exportFormatSelected = UartModuleManager.kExportFormats[saveDialogPopupButton.indexOfSelectedItem]
        if exportFormatSelected == .bin {
            exportFileDialog.nameFieldStringValue = "uart.bin"
        }
        else {
            exportFileDialog.nameFieldStringValue = "uart\(isInHexMode ? ".hex" : "").\(exportFormatSelected.rawValue)"
        }
        exportFileDialog.allowedFileTypes = [exportFormatSelected.rawValue]
    }
}

// MARK: - NSMenuDelegate
extension UartViewController: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
        updateSaveFileName()
    }
}

// MARK: - DetailTab
extension UartViewController: DetailTab {
    func tabWillAppear() {
        reloadDataUI()
        
        // Check if characteristics are ready
        let isUartReady = uartData.isReady()
        inputTextField.isEnabled = isUartReady
        inputTextField.backgroundColor = isUartReady ? NSColor.white : NSColor.black.withAlphaComponent(0.1)
    }
    
    func tabWillDissapear() {
        if !Config.uartShowAllUartCommunication {
            uartData.dataBufferEnabled = false
        }
    }
    
    func tabReset() {
        // Peripheral should be connected
        uartData.dataBufferEnabled = true
        uartData.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
    }
}

// MARK: - NSOpenSavePanelDelegate
extension UartViewController: NSOpenSavePanelDelegate {
    
}

// MARK: - NSTableViewDataSource
extension UartViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if (Preferences.uartIsEchoEnabled)  {
            tableCachedDataBuffer = uartData.dataBuffer
        }
        else {
            tableCachedDataBuffer = uartData.dataBuffer.filter({ (dataChunk : UartDataChunk) -> Bool in
                dataChunk.mode == .rx
            })
        }
        
        return tableCachedDataBuffer!.count
    }
}

// MARK: NSTableViewDelegate
extension UartViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var cell : NSTableCellView?
        
        let dataChunk = tableCachedDataBuffer![row]
        
        if let columnIdentifier = tableColumn?.identifier {
            switch(columnIdentifier) {
            case "TimestampColumn":
                cell = tableView.make(withIdentifier: "TimestampCell", owner: self) as? NSTableCellView
                
                let date = Date(timeIntervalSinceReferenceDate: dataChunk.timestamp)
                let dateString = timestampDateFormatter.string(from: date)
                cell!.textField!.stringValue = dateString
                
            case "DirectionColumn":
                cell = tableView.make(withIdentifier: "DirectionCell", owner: self) as? NSTableCellView
                
                cell!.textField!.stringValue = dataChunk.mode == .rx ? "RX" : "TX"
                
            case "DataColumn":
                cell = tableView.make(withIdentifier: "DataCell", owner: self) as? NSTableCellView
                
                let color = dataChunk.mode == .tx ? txColor : rxColor
                
                if let attributedText = UartModuleManager.attributeTextFromData(dataChunk.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: UartViewController.dataFont) {
                    //DLog("row \(row): \(attributedText.string)")
                    
                    // Display
                    cell!.textField!.attributedStringValue = attributedText
                    
                    // Update column width (if needed)
                    let width = attributedText.size().width
                    tableModeDataMaxWidth = max(tableColumn!.width, width)
                    DispatchQueue.main.async(execute: {     // Important: Execute async. This change should be done outside the delegate method to avoid weird reuse cell problems (reused cell shows old data and cant be changed).
                        if (tableColumn!.width < self.tableModeDataMaxWidth) {
                            tableColumn!.width = self.tableModeDataMaxWidth
                        }
                    });
                }
                else {
                    //DLog("row \(row): <empty>")
                    cell!.textField!.attributedStringValue = NSAttributedString()
                }
                
                
            default:
                cell = nil
            }
        }
        
        return cell;
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
    }
    
    func tableViewColumnDidResize(_ notification: Notification) {
        if let tableColumn = notification.userInfo?["NSTableColumn"] as? NSTableColumn {
            if (tableColumn.identifier == "DataColumn") {
                // If the window is resized, maintain the column width
                if (tableColumn.width < tableModeDataMaxWidth) {
                    tableColumn.width = tableModeDataMaxWidth
                }
                //DLog("column: \(tableColumn), width: \(tableColumn.width)")
            }
        }
    }
}

// MARK: - UartModuleDelegate
extension UartViewController: UartModuleDelegate {
    func addChunkToUI(_ dataChunk : UartDataChunk) {
        // Check that the view has been initialized before updating UI
        guard baseTableView != nil else {
            return;
        }
        
        let displayMode = Preferences.uartIsDisplayModeTimestamp ? UartModuleManager.DisplayMode.table : UartModuleManager.DisplayMode.text
        
        switch(displayMode) {
        case .text:
            if let textStorage = self.baseTextView.textStorage {
                let isScrollAtTheBottom = baseTextView.enclosingScrollView?.verticalScroller?.floatValue == 1
                
                addChunkToUIText(dataChunk)
                
                if isScrollAtTheBottom {
                    // if scroll was at the bottom then autoscroll to the new bottom
                    baseTextView.scrollRangeToVisible(NSMakeRange(textStorage.length, 0))
                }
            }
            
        case .table:
            let isScrollAtTheBottom = tableCachedDataBuffer == nil || tableCachedDataBuffer!.isEmpty || NSLocationInRange(tableCachedDataBuffer!.count-1, baseTableView.rows(in: baseTableView.visibleRect))
            //let isScrollAtTheBottom = tableCachedDataBuffer == nil || tableCachedDataBuffer!.isEmpty  || baseTableView.enclosingScrollView?.verticalScroller?.floatValue == 1
            
            baseTableView.reloadData()
            if isScrollAtTheBottom {
                // if scroll was at the bottom then autoscroll to the new bottom
                baseTableView.scrollToEndOfDocument(nil)
            }
        }
        
        updateBytesUI()
    }
    
    fileprivate func addChunkToUIText(_ dataChunk : UartDataChunk) {
        
        if (Preferences.uartIsEchoEnabled || dataChunk.mode == .rx) {
            let color = dataChunk.mode == .tx ? txColor : rxColor
            
            let attributedString = UartModuleManager.attributeTextFromData(dataChunk.data, useHexMode: Preferences.uartIsInHexMode, color: color, font: UartViewController.dataFont)
            
            if let textStorage = self.baseTextView.textStorage, let attributedString = attributedString {
                textStorage.append(attributedString)
            }
        }
    }

    func mqttUpdateStatusUI() {
        let status = MqttManager.sharedInstance.status
        
        let localizationManager = LocalizationManager.sharedInstance
        var buttonTitle = localizationManager.localizedString("uart_mqtt_status_default")
        
        switch (status) {
        case .connecting:
            buttonTitle = localizationManager.localizedString("uart_mqtt_status_connecting")
            
            
        case .connected:
            buttonTitle = localizationManager.localizedString("uart_mqtt_status_connected")
            
            
        default:
            buttonTitle = localizationManager.localizedString("uart_mqtt_status_disconnected")
            
        }
        
        mqttStatusButton.title = buttonTitle
    }
    
    func mqttError(_ message: String, isConnectionError: Bool) {
        let localizationManager = LocalizationManager.sharedInstance
        let alert = NSAlert()
        alert.messageText = isConnectionError ? localizationManager.localizedString("uart_mqtt_connectionerror_title"): message
        alert.addButton(withTitle: localizationManager.localizedString("dialog_ok"))
        if (isConnectionError) {
            alert.addButton(withTitle: localizationManager.localizedString("uart_mqtt_editsettings_action"))
            alert.informativeText = message
        }
        alert.alertStyle = .warning
        alert.beginSheetModal(for: self.view.window!, completionHandler: { [unowned self] (returnCode) -> Void in
            if isConnectionError && returnCode == NSAlertSecondButtonReturn {
                let preferencesViewController = self.storyboard?.instantiateController(withIdentifier: "PreferencesViewController") as! PreferencesViewController
                self.presentViewControllerAsModalWindow(preferencesViewController)
            }
        }) 
    }
}

// MARK: - CBPeripheralDelegate
extension UartViewController: CBPeripheralDelegate {
    // Pass peripheral callbacks to UartData
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        uartData.peripheral(peripheral, didModifyServices: invalidatedServices)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        uartData.peripheral(peripheral, didDiscoverServices:error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        uartData.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
        
        // Check if ready
        if uartData.isReady() {
            // Enable input
            DispatchQueue.main.async(execute: { [unowned self] in
                if self.inputTextField != nil {     // could be nil if the viewdidload has not been executed yet
                    self.inputTextField.isEnabled = true
                    self.inputTextField.backgroundColor = NSColor.white
                }
                });
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
      uartData.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
    }
}

