//
//  DfuUpdateProcess.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 09/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

protocol DfuUpdateProcessDelegate: class {
    func onUpdateProcessSuccess()
    func onUpdateProcessError(_ errorMessage: String, infoMessage: String?)
    func onUpdateProgressText(_ message: String)
    func onUpdateProgressValue(_ progress: Double)
}

class DfuUpdateProcess : NSObject {
    
    fileprivate static let kApplicationHexFilename = "application.hex"
    fileprivate static let kApplicationIniFilename = "application.bin"     // don't change extensions. dfuOperations will look for these specific extensions
    
    // Parameters
    fileprivate var peripheral: CBPeripheral?
    fileprivate var hexUrl: URL?
    fileprivate var iniUrl: URL?
    fileprivate var deviceInfoData : DeviceInfoData?
    weak var delegate: DfuUpdateProcessDelegate?
    
    // DFU data
    fileprivate var dfuOperations : DFUOperations?
    fileprivate var isDfuStarted = false
    fileprivate var isDFUCancelled = false
    
    fileprivate var isConnected = false
    fileprivate var isDFUVersionExits = false
    fileprivate var isTransferring  = false
    fileprivate var dfuVersion: Int32 = -1
    
    fileprivate var currentTransferPercentage: Int32 = -1
    
    func startUpdateForPeripheral(_ peripheral: CBPeripheral, hexUrl: URL, iniUrl: URL?, deviceInfoData: DeviceInfoData) {
        self.peripheral = peripheral
        self.hexUrl = hexUrl
        self.iniUrl = iniUrl
        self.deviceInfoData = deviceInfoData
        currentTransferPercentage = -1
        
        dfuOperations = DFUOperations(delegate: self)
        
        // Download files
        delegate?.onUpdateProgressText("Opening hex file")      // command line doesnt have localizationManager
        //delegate?.onUpdateProgressText(LocalizationManager.sharedInstance.localizedString("dfu_download_hex_message"))
        DataDownloader.downloadData(from: hexUrl) {[weak self] (data) -> Void in
            self?.downloadedFirmwareData(data)
        }
    }
    
    fileprivate func downloadedFirmwareData(_ data: Data?) {
        // Single hex file needed
        if let data = data {
            let bootloaderVersion = deviceInfoData!.bootloaderVersion()
            let useHexOnly = bootloaderVersion == deviceInfoData!.defaultBootloaderVersion()
            if (useHexOnly) {
                let path = (NSTemporaryDirectory() as NSString).appendingPathComponent(DfuUpdateProcess.kApplicationHexFilename)
                let fileUrl = URL(fileURLWithPath: path)
                try? data.write(to: fileUrl, options: [.atomic])
                startDfuOperation()
            }
            else {
                delegate?.onUpdateProgressText("Opening init file")     // command line doesnt have localizationManager
                //delegate?.onUpdateProgressText(LocalizationManager.sharedInstance.localizedString("dfu_download_init_message"))
                DataDownloader.downloadData(from: iniUrl, withCompletionHandler: {[weak self]  (iniData) -> Void in
                    self?.downloadedFirmwareHexAndInitData(data, iniData: iniData)
                    })
            }
        }
        else {
            showSoftwareDownloadError()
        }
    }
    
    fileprivate func downloadedFirmwareHexAndInitData(_ hexData: Data?, iniData: Data?) {
        //  hex + dat file needed
        if (hexData != nil && iniData != nil)
        {
            let hexPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(DfuUpdateProcess.kApplicationHexFilename)
            let hexFileUrl = URL(fileURLWithPath: hexPath)
            let hexDataWritten = (try? hexData!.write(to: hexFileUrl, options: [.atomic])) != nil
            if (!hexDataWritten) {
                DLog("Error saving hex file")
            }
            
            let initPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(DfuUpdateProcess.kApplicationIniFilename)
            let iniFileUrl = URL(fileURLWithPath: initPath)
            let initDataWritten = (try? iniData!.write(to: iniFileUrl, options: [.atomic])) != nil
            if (!initDataWritten) {
                DLog("Error saving ini file")
            }
            
            startDfuOperation()
        }
        else {
            showSoftwareDownloadError()
        }
    }
    
    fileprivate func showSoftwareDownloadError() {
        delegate?.onUpdateProcessError("Software download error", infoMessage: "Please check your internet connection and try again later")
    }
    
    fileprivate func startDfuOperation() {
        guard let peripheral = peripheral else {
            DLog("startDfuOperation error: No peripheral defined")
            return
        }
        
        DLog("startDfuOperation");
        isDfuStarted = false
        isDFUCancelled = false
        delegate?.onUpdateProgressText("DFU Init")
        
        // Files should be ready at NSTemporaryDirectory/application.hex (and application.dat if needed)
        if let centralManager = BleManager.sharedInstance.centralManager {
            //            BleManager.sharedInstance.stopScan()
            
            dfuOperations = DFUOperations(delegate: self)
            dfuOperations!.setCentralManager(centralManager)
            dfuOperations!.connectDevice(peripheral)
        }
    }
    
    /*
    func startDfuOperationBypassingChecksWithPeripheral(peripheral: CBPeripheral, hexData: NSData, iniData: NSData?) -> Bool {
        // This funcion bypass all checks and start the dfu operation with the data provided. Used by the command line app
        
        // Set peripheral
        self.peripheral = peripheral
        
        // Simulate deviceInfoData. Fake the bootloaderversion to the defaultBootloaderVersion if only an hex file is provided or a newer version if both hex and ini files are provided
        deviceInfoData = DeviceInfoData()
        if iniData != nil {
            deviceInfoData?.firmwareRevision = ", 1.0"
        }
        
        // Copy files to where dfu will read them
        let hexPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(DfuUpdateProcess.kApplicationHexFilename)
        let hexFileUrl = NSURL.fileURLWithPath(hexPath)
        let hexDataWritten = hexData.writeToURL(hexFileUrl, atomically: true)
        if (!hexDataWritten) {
            DLog("Error saving hex file")
            return false
        }
        
        if let iniData = iniData {
            let initPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(DfuUpdateProcess.kApplicationIniFilename)
            let iniFileUrl = NSURL.fileURLWithPath(initPath)
            let initDataWritten = iniData.writeToURL(iniFileUrl, atomically: true)
            if (!initDataWritten) {
                DLog("Error saving ini file")
                return false
            }
        }

        startDfuOperation()
        return true
    }
    */
    
    func cancel() {
        // Cancel current operation
        dfuOperations?.cancelDFU()
    }
}

// MARK: - DFUOperationsDelegate
extension DfuUpdateProcess : DFUOperationsDelegate {
    func onDeviceConnected(_ peripheral: CBPeripheral!) {
        DLog("DFUOperationsDelegate - onDeviceConnected");
        isConnected = true
        isDFUVersionExits = false
        dfuVersion = -1
        
    }
    
    func onDeviceConnected(withVersion peripheral: CBPeripheral!) {
        DLog("DFUOperationsDelegate - onDeviceConnectedWithVersion");
        isConnected = true
        isDFUVersionExits = true
        dfuVersion = -1
    }
    
    func onDeviceDisconnected(_ peripheral: CBPeripheral!) {
        DLog("DFUOperationsDelegate - onDeviceDisconnected");
        if (dfuVersion != 1) {
            isTransferring = false
            isConnected = false
            
            if (dfuVersion == 0)
            {
                onError("The legacy bootloader on this device is not compatible with this application")
            }
            else
            {
                onError("Update error")
            }
        }
        else {
            let delayInSeconds = 3.0;
            let delayTime = DispatchTime.now() + Double(Int64(delayInSeconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: delayTime) { [unowned self] in
                self.dfuOperations?.connectDevice(peripheral)
            }
        }
    }
    
    func onReadDFUVersion(_ version: Int32) {
        DLog("DFUOperationsDelegate - onReadDFUVersion: \(version)")
        
        guard dfuOperations != nil && deviceInfoData != nil else {
            onError("Internal error")
            return
        }
        
        dfuVersion = version;
        if (dfuVersion == 1) {
            delegate?.onUpdateProgressText("DFU set bootloader mode")
            dfuOperations!.setAppToBootloaderMode()
        }
        else if (dfuVersion > 1 && !isDFUCancelled && !isDfuStarted)
        {
            // Ready to start
            isDfuStarted = true
            let bootloaderVersion = deviceInfoData!.bootloaderVersion()
            let defaultBootloaderVersion  = deviceInfoData!.defaultBootloaderVersion()
            let useHexOnly = (bootloaderVersion == defaultBootloaderVersion)
            
            DLog("Updating")
            delegate?.onUpdateProgressText("Updating")
            if (useHexOnly)
            {
                let fileURL = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent(DfuUpdateProcess.kApplicationHexFilename))
                dfuOperations!.performDFU(onFile: fileURL, firmwareType: APPLICATION)
            }
            else {
                let hexFileURL = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent(DfuUpdateProcess.kApplicationHexFilename))
                let iniFileURL = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent(DfuUpdateProcess.kApplicationIniFilename))
                
                dfuOperations!.performDFUOnFile(withMetaData: hexFileURL, firmwareMetaDataURL: iniFileURL, firmwareType: APPLICATION)
            }
        }
    }
    
    func onDFUStarted() {
        DLog("DFUOperationsDelegate - onDFUStarted")
        isTransferring = true
    }
    
    func onDFUCancelled() {
        DLog("DFUOperationsDelegate - onDFUCancelled")
        
        // Disconnected while updating
        isDFUCancelled = true
        onError("Update cancelled")
    }
    
    func onSoftDeviceUploadStarted() {
        DLog("DFUOperationsDelegate - onSoftDeviceUploadStarted")
        
    }
    
    func onSoftDeviceUploadCompleted() {
        DLog("DFUOperationsDelegate - onBootloaderUploadStarted")
        
    }
    
    func onBootloaderUploadStarted() {
        DLog("DFUOperationsDelegate - onSoftDeviceUploadCompleted")
        
    }
    
    func onBootloaderUploadCompleted() {
        DLog("DFUOperationsDelegate - onBootloaderUploadCompleted")
        
    }
    
    
    func onTransferPercentage(_ percentage: Int32) {
        DLog("DFUOperationsDelegate - onTransferPercentage: \(percentage)")
        
        if currentTransferPercentage != percentage {
            currentTransferPercentage = percentage
            DispatchQueue.main.async(execute: { [weak self] in
                self?.delegate?.onUpdateProgressValue(Double(percentage))
                })
        }
    }
    
    func onSuccessfulFileTranferred() {
        DLog("DFUOperationsDelegate - onSuccessfulFileTranferred")
        
        DispatchQueue.main.async(execute: {  [weak self] in
            self?.delegate?.onUpdateProcessSuccess()
            })
    }
    
    func onError(_ errorMessage: String!) {
        
        DLog("DFUOperationsDelegate - onError: \(errorMessage)" )
        
        DispatchQueue.main.async(execute: { [weak self] in
            self?.delegate?.onUpdateProcessError(errorMessage, infoMessage: nil)
            })
    }
}
