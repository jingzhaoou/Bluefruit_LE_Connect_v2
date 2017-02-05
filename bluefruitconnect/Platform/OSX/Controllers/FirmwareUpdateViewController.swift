//
//  FirmwareUpdateViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class FirmwareUpdateViewController: NSViewController {
    
    // UI
    @IBOutlet weak var firmwareCurrentVersionLabel: NSTextField!
    @IBOutlet weak var firmwareCurrentVersionWaitView: NSProgressIndicator!
    @IBOutlet weak var firmwareTableView: NSTableView!
    @IBOutlet weak var firmwareWaitView: NSProgressIndicator!
    @IBOutlet weak var hexFileTextField: NSTextField!
    @IBOutlet weak var iniFileTextField: NSTextField!
    
    // Data
    fileprivate let firmwareUpdater = FirmwareUpdater()
    fileprivate let dfuUpdateProcess = DfuUpdateProcess()
    fileprivate var updateDialogViewController: UpdateDialogViewController?
    
    fileprivate var boardRelease: BoardInfo?
    fileprivate var deviceInfoData: DeviceInfoData?
    fileprivate var allReleases: [AnyHashable: Any]?
    
    fileprivate var isTabVisible = false
    fileprivate var isCheckingUpdates = false
    
    var infoFinishedScanning = false {
        didSet {
            if infoFinishedScanning != oldValue {
                DLog("updates infoFinishedScanning: \(infoFinishedScanning)")
                if infoFinishedScanning && isTabVisible {
                    startUpdatesCheck()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // UI
        firmwareWaitView.startAnimation(nil)
        firmwareCurrentVersionWaitView.startAnimation(nil)
        firmwareCurrentVersionLabel.stringValue = ""
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        registerNotifications(true)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        registerNotifications(false)
    }

    func startUpdatesCheck() {
        // Refresh updates available
        if !isCheckingUpdates {
            if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
                isCheckingUpdates = true
                let releases = FirmwareUpdater.releases(withBetaVersions: Preferences.showBetaVersions)
                firmwareUpdater.checkUpdates(for: blePeripheral.peripheral, delegate: self, shouldDiscoverServices: false, releases: releases, shouldRecommendBetaReleases: false)
            }
        }
    }

    // MARK: - Preferences
    func registerNotifications(_ register : Bool) {
        
        let notificationCenter =  NotificationCenter.default
        if (register) {
            notificationCenter.addObserver(self, selector: #selector(FirmwareUpdateViewController.preferencesUpdated(_:)), name: NSNotification.Name(rawValue: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue), object: nil)
        }
        else {
            notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: Preferences.PreferencesNotifications.DidUpdatePreferences.rawValue), object: nil)
        }
    }

    func preferencesUpdated(_ notification : Notification) {
        // Reload updates
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
            let releases = FirmwareUpdater.releases(withBetaVersions: Preferences.showBetaVersions)
            firmwareUpdater.checkUpdates(for: blePeripheral.peripheral, delegate: self, shouldDiscoverServices: false, releases: releases, shouldRecommendBetaReleases: false)
        }
    }

    // MARK: - 
    
    @IBAction func onClickChooseInitFile(_ sender: AnyObject) {
        chooseFile(false)
    }
    
    @IBAction func onClickChooseHexFile(_ sender: AnyObject) {
        chooseFile(true)
    }
    
    func chooseFile(_ isHexFile : Bool) {
        let openFileDialog = NSOpenPanel()
        openFileDialog.canChooseFiles = true
        openFileDialog.canChooseDirectories = false
        openFileDialog.allowsMultipleSelection = false
        openFileDialog.canCreateDirectories = false
        
        if let window = self.view.window {
            openFileDialog.beginSheetModal(for: window) {[unowned self] (result) -> Void in
                if result == NSFileHandlingPanelOKButton {
                    if let url = openFileDialog.url {
                        
                        if (isHexFile) {
                            self.hexFileTextField.stringValue = url.path
                        }
                        else {
                            self.iniFileTextField.stringValue = url.path
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func onClickCustomFirmwareUpdate(_ sender: AnyObject) {
        guard deviceInfoData != nil else {
            DLog("deviceInfoData is nil");
            return
        }
        
        guard !deviceInfoData!.hasDefaultBootloaderVersion() else {
            onUpdateProcessError("The legacy bootloader on this device is not compatible with this application", infoMessage: nil)
            return
        }

        guard !hexFileTextField.stringValue.isEmpty else {
            onUpdateProcessError("At least an Hex file should be selected", infoMessage: nil)
            return
        }
        
        let hexUrl = URL(fileURLWithPath: hexFileTextField.stringValue)
        var iniUrl :URL? = nil
        
        if !iniFileTextField.stringValue.isEmpty {
            iniUrl = URL(fileURLWithPath: iniFileTextField.stringValue)
        }
        
        startDfuUpdateWithHexInitFiles(hexUrl, iniUrl: iniUrl)
    }
       
    // MARK: - DFU update
    func confirmDfuUpdateWithFirmware(_ firmwareInfo : FirmwareInfo) {
        let compareBootloader = deviceInfoData!.bootloaderVersion().caseInsensitiveCompare(firmwareInfo.minBootloaderVersion)
        if (compareBootloader == .orderedDescending || compareBootloader == .orderedSame) {        // Requeriments met
            let alert = NSAlert()
            alert.messageText = "Install firmware version \(firmwareInfo.version)?"
            alert.informativeText = "The firmware will be downloaded and updated. Please wait until the process finishes before disconnecting the peripheral"
            alert.addButton(withTitle: "Ok")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!, completionHandler: { [unowned self](modalResponse) -> Void in
                if (modalResponse == NSAlertFirstButtonReturn) {
                    self.startDfuUpdateWithFirmware(firmwareInfo)
                }
            })
        }
        else {      // Requeriments not met
            let alert = NSAlert()
            alert.messageText = "This firmware update is not compatible with your bootloader. You need to update your bootloader to version %@ before installing this firmware release \(firmwareInfo.version)"
            alert.addButton(withTitle: "Ok")
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
        }
    }
    
    func startDfuUpdateWithFirmware(_ firmwareInfo : FirmwareInfo) {
        let hexUrl = URL(string: firmwareInfo.hexFileUrl)!
        let iniUrl =  URL(string: firmwareInfo.iniFileUrl)
        startDfuUpdateWithHexInitFiles(hexUrl, iniUrl: iniUrl)
    }
    
    func startDfuUpdateWithHexInitFiles(_ hexUrl : URL, iniUrl: URL?) {
        if let blePeripheral = BleManager.sharedInstance.blePeripheralConnected {
     
            // Setup update process
            dfuUpdateProcess.startUpdateForPeripheral(blePeripheral.peripheral, hexUrl: hexUrl, iniUrl:iniUrl, deviceInfoData: deviceInfoData!)
            dfuUpdateProcess.delegate = self

            // Show dialog
            updateDialogViewController = (self.storyboard?.instantiateController(withIdentifier: "UpdateDialogViewController") as! UpdateDialogViewController)
            updateDialogViewController!.delegate = self
            self.presentViewControllerAsModalWindow(updateDialogViewController!)
        }
        else {
            onUpdateProcessError("No peripheral conected. Abort update", infoMessage: nil);
        }
    }
}

// MARK: - DetailTab
extension FirmwareUpdateViewController : DetailTab {
    func tabWillAppear() {
        isTabVisible = true
        if infoFinishedScanning {
            startUpdatesCheck()
        }
    }
    
    func tabWillDissapear() {
        isTabVisible = false
    }
    
    func tabReset() {
        isCheckingUpdates = false
        boardRelease = nil
        deviceInfoData = nil
    }
}

// MARK: - FirmwareUpdaterDelegate
extension FirmwareUpdateViewController : FirmwareUpdaterDelegate {
    func onFirmwareUpdatesAvailable(_ isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData?, allReleases: [AnyHashable: Any]?) {
        DLog("onFirmwareUpdatesAvailable")
        
        self.deviceInfoData = deviceInfoData
        
        self.allReleases = allReleases
        if let allReleases = allReleases {
            if let modelNumber = deviceInfoData?.modelNumber {
                boardRelease = allReleases[modelNumber] as? BoardInfo
            }
            else {
                DLog("Warning: no releases found for this board")
                boardRelease = nil
            }
        }
        else {
            DLog("Warning: no releases found")
        }
        
        // Update UI
        
        DispatchQueue.main.async(execute: { [unowned self] in
            self.firmwareWaitView.stopAnimation(nil)
            self.firmwareTableView.reloadData()
            
            self.firmwareCurrentVersionLabel.stringValue = "<Unknown>"
            if let deviceInfoData = deviceInfoData {
                if (deviceInfoData.hasDefaultBootloaderVersion()) {
                    self.onUpdateProcessError("The legacy bootloader on this device is not compatible with this application", infoMessage: nil)
                }
                if (deviceInfoData.softwareRevision != nil) {
                    self.firmwareCurrentVersionLabel.stringValue = deviceInfoData.softwareRevision
                }
            }
            
            self.firmwareCurrentVersionWaitView.stopAnimation(nil)
            })
    }
    
    func onDfuServiceNotFound() {
        onUpdateProcessError("No DFU Service found on device", infoMessage: nil)
    }
}

// MARK: - NSTableViewDataSource
extension FirmwareUpdateViewController : NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if let firmwareReleases = boardRelease?.firmwareReleases {
            return firmwareReleases.count
        }
        else {
            // Show all releases
            var numReleases = 0
            if let allReleases = allReleases {
                for (_, value) in allReleases {
                    let boardInfo = value as! BoardInfo
                    numReleases += boardInfo.firmwareReleases.count
                }
            }
            return numReleases
        }
    }
}

// MARK: NSTableViewDelegate
extension FirmwareUpdateViewController : NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        let firmwareInfo = firmwareInfoForRow(row)
        
        var cell = NSTableCellView()
        
        if let columnIdentifier = tableColumn?.identifier {
            switch columnIdentifier {
            case "VersionColumn":
                cell = tableView.make(withIdentifier: "FirmwareVersionCell", owner: self) as! NSTableCellView
                
                var text = firmwareInfo.version
                if text == nil {
                    text = "<unknown>"
                }
                if firmwareInfo.isBeta {
                    text! += " Beta"
                }
                cell.textField?.stringValue = text!
                
            case "TypeColumn":
                cell = tableView.make(withIdentifier: "FirmwareTypeCell", owner: self) as! NSTableCellView
                
                cell.textField?.stringValue = firmwareInfo.boardName
                
            default:
                cell.textField?.stringValue = ""
            }
        }
        
        return cell;
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        
        let selectedRow = firmwareTableView.selectedRow
        if selectedRow >= 0 {
            if (deviceInfoData!.hasDefaultBootloaderVersion()) {
                onUpdateProcessError("The legacy bootloader on this device is not compatible with this application", infoMessage: nil)
            }
            else {
                let firmwareInfo = firmwareInfoForRow(selectedRow)
                
                confirmDfuUpdateWithFirmware(firmwareInfo)
                firmwareTableView.deselectAll(nil)
            }
        }
        
    }
    
    fileprivate func firmwareInfoForRow(_ row: Int) -> FirmwareInfo {
        var firmwareInfo: FirmwareInfo!
        
        if let firmwareReleases: NSArray = boardRelease?.firmwareReleases {     // If showing releases for a specific board
            let firmwareInfos = firmwareReleases as! [FirmwareInfo]
            firmwareInfo = firmwareInfos[row]
        }
        else {      // If showing all available releases
            var currentRow = 0
            var currentBoardIndex = 0
            while currentRow <= row {
                
                let sortedKeys = allReleases!.keys.sorted(by: {($0 as! String) < ($1 as! String)})        // Order alphabetically
                let currentKey = sortedKeys[currentBoardIndex]
                let boardRelease = allReleases![currentKey] as! BoardInfo
                
                        // order versions numerically
                let firmwareReleases = boardRelease.firmwareReleases.sorted(by: { (firmwareA, firmwareB) -> Bool in
                    let versionA = (firmwareA as! FirmwareInfo).version
                    let versionB = (firmwareB as! FirmwareInfo).version
                    return versionA!.compare(versionB!, options: .numeric) == .orderedAscending
                })
                    
                let numReleases = firmwareReleases.count
                let remaining = row - currentRow
                if remaining < numReleases {
                    firmwareInfo = firmwareReleases[remaining] as! FirmwareInfo
                }
                else {
                    currentBoardIndex += 1
                }
                currentRow += numReleases
            }
        }

        return firmwareInfo
    }
}

// MARK: - UpdateDialogViewControlerDelegate
extension FirmwareUpdateViewController : UpdateDialogControllerDelegate {
    
    func onUpdateDialogCancel() {
        
        dfuUpdateProcess.cancel()
        BleManager.sharedInstance.restoreCentralManager()

        if let updateDialogViewController = updateDialogViewController {
            dismissViewController(updateDialogViewController);
            self.updateDialogViewController = nil
        }
        

        updateDialogViewController = nil
    }
}

// MARK: - DfuUpdateProcessDelegate
extension FirmwareUpdateViewController : DfuUpdateProcessDelegate {
    func onUpdateProcessSuccess() {
        BleManager.sharedInstance.restoreCentralManager()
        
        if let updateDialogViewController = updateDialogViewController {
            dismissViewController(updateDialogViewController);
            self.updateDialogViewController = nil
        }
        
        if let window = self.view.window {
            let alert = NSAlert()
            alert.messageText = "Update completed successfully"
            alert.addButton(withTitle: "Ok")
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
        else {
            DLog("onUpdateDialogSuccess: window not defined")
        }
    }
    
    func onUpdateProcessError(_ errorMessage : String, infoMessage: String?) {
        BleManager.sharedInstance.restoreCentralManager()
        
        if let updateDialogViewController = updateDialogViewController {
            dismissViewController(updateDialogViewController);
            self.updateDialogViewController = nil
        }
        
        if let window = self.view.window {
            let alert = NSAlert()
            alert.messageText = errorMessage
            if let infoMessage = infoMessage {
                alert.informativeText = infoMessage
            }
            alert.addButton(withTitle: "Ok")
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
        else {
            DLog("onUpdateDialogError: window not defined when showing dialog with message: \(errorMessage)")
        }
    }
    
    func onUpdateProgressText(_ message: String) {
        updateDialogViewController?.setProgressText(message)
    }
    
    func onUpdateProgressValue(_ progress : Double) {
        updateDialogViewController?.setProgress(progress)
    }
}

// MARK: - CBPeripheralDelegate
extension FirmwareUpdateViewController: CBPeripheralDelegate {
    // Pass peripheral callbacks to UartData
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog("FirmwareUpdateViewController didModifyServices")
        
        if infoFinishedScanning {
            DLog("didModify servies updates check")
            isCheckingUpdates = false
            startUpdatesCheck()
        }
    }
    
}


