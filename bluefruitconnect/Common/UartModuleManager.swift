//
//  UartData.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

protocol UartModuleDelegate: class {
    func addChunkToUI(_ dataChunk: UartDataChunk)
    func mqttUpdateStatusUI()
    func mqttError(_ message: String, isConnectionError: Bool)
}

// Wrapper around UartManager to implenent an UartModule
class UartModuleManager: NSObject {
    enum DisplayMode {
        case text           // Display a TextView with all uart data as a String
        case table          // Display a table where each data chunk is a row
    }
    
    enum ExportFormat: String {
        case txt = "txt"
        case csv = "csv"
        case json = "json"
        case xml = "xml"
        case bin = "bin"
    }
    
    // Proxies
    var blePeripheral : BlePeripheral? {
        get {
        return UartManager.sharedInstance.blePeripheral
        }
        set {
            UartManager.sharedInstance.blePeripheral = newValue
        }
    }
    
    var dataBufferEnabled : Bool {
        set {
            UartManager.sharedInstance.dataBufferEnabled = newValue
        }
        get {
            return UartManager.sharedInstance.dataBufferEnabled
        }
    }
    
    var dataBuffer : [UartDataChunk] {
        return UartManager.sharedInstance.dataBuffer
    }
    
    // Current State
    weak var delegate: UartModuleDelegate?
    
    // Export
    #if os(OSX)
    static let kExportFormats: [ExportFormat] = [.txt, .csv, .json, .xml, .bin]
    #else
    static let kExportFormats: [ExportFormat] = [.txt, .csv, .json/*, .xml*/, .bin]
    #endif
    
    override init() {
        super.init()
        
        let notificationCenter =  NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(didReceiveData(_:)), name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidReceiveData.rawValue), object: nil)
    }
    
    deinit {
        let notificationCenter =  NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidReceiveData.rawValue), object: nil)
    }
    
    // MARK: - Uart
    func sendMessageToUart(_ text: String) {
        sendMessageToUart(text, wasReceivedFromMqtt: false)
    }
    
    func sendMessageToUart(_ text: String, wasReceivedFromMqtt: Bool) {
        
        // Mqtt publish to TX
        let mqttSettings = MqttSettings.sharedInstance
        if(mqttSettings.isPublishEnabled) {
            if let topic = mqttSettings.getPublishTopic(MqttSettings.PublishFeed.tx.rawValue) {
                let qos = mqttSettings.getPublishQos(MqttSettings.PublishFeed.tx.rawValue)
                MqttManager.sharedInstance.publish(text, topic: topic, qos: qos)
            }
        }
        
        // Create data and send to Uart
        if let data = text.data(using: String.Encoding.utf8) {
            let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .tx, data: data)
            
            DispatchQueue.main.async(execute: {[unowned self] in
                self.delegate?.addChunkToUI(dataChunk)
                })
            
            if (!wasReceivedFromMqtt || mqttSettings.subscribeBehaviour == .transmit) {
                UartManager.sharedInstance.sendChunk(dataChunk)
            }
        }
    }
    
    func didReceiveData(_ notification: Notification) {
        if let dataChunk = notification.userInfo?["dataChunk"] as? UartDataChunk {
            receivedChunk(dataChunk)
        }
    }
    
    fileprivate func receivedChunk(_ dataChunk: UartDataChunk) {
        
        // Mqtt publish to RX
        let mqttSettings = MqttSettings.sharedInstance
        if mqttSettings.isPublishEnabled {
            if let message = NSString(data: dataChunk.data as Data, encoding: String.Encoding.utf8.rawValue) {
                if let topic = mqttSettings.getPublishTopic(MqttSettings.PublishFeed.rx.rawValue) {
                    let qos = mqttSettings.getPublishQos(MqttSettings.PublishFeed.rx.rawValue)
                    MqttManager.sharedInstance.publish(message as String, topic: topic, qos: qos)
                }
            }
        }

        // Add to UI
        DispatchQueue.main.async(execute: {[unowned self] in
            self.delegate?.addChunkToUI(dataChunk)
            })
        
    }
    
    
    func isReady() -> Bool {
        return UartManager.sharedInstance.isReady()
    }
    
    func clearData() {
        UartManager.sharedInstance.clearData()
    }
    
    // MARK: - UI Utils
    static func attributeTextFromData(_ data: Data, useHexMode: Bool, color: Color, font: Font) -> NSAttributedString? {
        var attributedString : NSAttributedString?
        
        let textAttributes: [String:AnyObject] = [NSFontAttributeName: font, NSForegroundColorAttributeName: color]
        
        if (useHexMode) {
            let hexValue = hexString(data)
            attributedString = NSAttributedString(string: hexValue, attributes: textAttributes)
        }
        else {
            if let value = NSString(data:data, encoding: String.Encoding.ascii.rawValue) as String? {
                
                var representableValue: String
                
                if Preferences.uartShowInvisibleChars {
                    representableValue = ""
                    for scalar in value.unicodeScalars {
                        let isRepresentable = scalar.value>=32 && scalar.value<127
                        //DLog("\(scalar.value). isVis: \( isRepresentable ? "true":"false" )")
                        representableValue.append(String(describing: isRepresentable ? scalar:UnicodeScalar("�")))
                    }
                }
                else {
                    representableValue = value
                }
                
                attributedString = NSAttributedString(string: representableValue, attributes: textAttributes)
            }
        }
        
        return attributedString
    }
}

// MARK: - CBPeripheralDelegate
extension UartModuleManager: CBPeripheralDelegate {
    // Pass peripheral callbacks to UartData
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        UartManager.sharedInstance.peripheral(peripheral, didModifyServices: invalidatedServices)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        UartManager.sharedInstance.peripheral(peripheral, didDiscoverServices:error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        UartManager.sharedInstance.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        UartManager.sharedInstance.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
    }
}

// MARK: - MqttManagerDelegate
extension UartModuleManager: MqttManagerDelegate {
    func onMqttConnected() {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.delegate?.mqttUpdateStatusUI()
            })
    }
    
    func onMqttDisconnected() {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.delegate?.mqttUpdateStatusUI()
            })
        
    }
    
    func onMqttMessageReceived(_ message: String, topic: String) {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.sendMessageToUart(message, wasReceivedFromMqtt: true)
            })
    }
    
    func onMqttError(_ message: String) {
        let mqttManager = MqttManager.sharedInstance
        let status = mqttManager.status
        let isConnectionError = status == .connecting
        
        DispatchQueue.main.async(execute: { [unowned self] in
            self.delegate?.mqttError(message, isConnectionError: isConnectionError)
            })
    }
}
