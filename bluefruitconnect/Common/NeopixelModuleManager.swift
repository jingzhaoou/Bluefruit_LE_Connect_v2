//
//  NeopixelModuleManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 24/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreImage

protocol NeopixelModuleManagerDelegate: class {
    func onNeopixelUartIsReady()
    func onNeopixelSketchDetected(_ detected: Bool)
    func onNeopixelSetupFinished(_ sucess: Bool)
}

class NeopixelModuleManager: NSObject {
    // Constants
    fileprivate static let kUartTimeout = 2.0               // seconds
    static let kDefaultType: UInt16 = 82       // default value: NEO_GRB + NEO_KHZ800
    
    //
    struct Board {
        var name = "<No name>"
        var width: UInt8 = 0, height: UInt8 = 0
        var components: UInt8 = 3
        var stride: UInt8 = 0
        var type: UInt16 = kDefaultType
        
        static func loadStandardBoard(_ standardIndex: Int, type: UInt16 = kDefaultType) -> Board {
            let path = Bundle.main.path(forResource: "NeopixelBoards", ofType: "plist")!
            let boards = NSArray(contentsOfFile: path) as? [[String: AnyObject]]
            
            let boardData = boards![standardIndex]
            let name = boardData["name"] as! String
            let width = UInt8((boardData["width"] as! NSNumber).intValue)
            let height = UInt8((boardData["height"] as! NSNumber).intValue)
            let components = UInt8((boardData["components"] as! NSNumber).intValue)
            let stride = UInt8((boardData["stride"] as! NSNumber).intValue)
            
            let board = NeopixelModuleManager.Board(name: name, width: width, height: height, components: components, stride: stride, type: type)
            return board
        }
    }
    
    // Delegate
    weak var delegate: NeopixelModuleManagerDelegate?
    
    // Bluetooth Uart
    fileprivate let uartData = UartManager.sharedInstance
    fileprivate var uartResponseDelegate : ((Data?)->Void)?
    fileprivate var uartResponseTimer : Timer?
    
    // Neopixel
    var isSketchDetected : Bool?
    var isWaitingResponse: Bool {
        return uartResponseDelegate != nil
    }
    var board: Board?
    
    func start() {
        DLog("neopixel start");
        
        // Start Uart Manager
        UartManager.sharedInstance.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
        
        // Notifications
        let notificationCenter =  NotificationCenter.default
        if !uartData.isReady() {
            notificationCenter.addObserver(self, selector: #selector(NeopixelModuleManager.uartIsReady(_:)), name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        }
        notificationCenter.addObserver(self, selector: #selector(NeopixelModuleManager.didReceiveData(_:)), name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidReceiveData.rawValue), object: nil)
    }
    
    func stop() {
        DLog("neopixel stop");
        let notificationCenter =  NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidReceiveData.rawValue), object: nil)
        
        uartResponseDelegate = nil
        cancelUartResponseTimer()
    }
    
    deinit {
        DLog("neopixel deinit")
        stop()
    }
    
    func isReady() -> Bool {
        return uartData.isReady()
    }
    
    func isBoardConfigured() -> Bool {
        return board != nil
    }
    
    func connectNeopixel() {
        self.checkNeopixelSketch()
    }
    
    // MARK: Notifications
    func uartIsReady(_ notification: Notification) {
        DLog("Uart is ready")
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        
        delegate?.onNeopixelUartIsReady()
    }
    
    
    // MARK: - Uart
    fileprivate func sendDataToUart(_ data: Data, completionHandler: @escaping (_ response: Data?)->Void) {
        guard uartResponseDelegate == nil && uartResponseTimer == nil else {
            DLog("sendDataToUart error: waiting for a previous response")
            return
        }
        
        uartResponseTimer = Timer.scheduledTimer(timeInterval: NeopixelModuleManager.kUartTimeout, target: self, selector: #selector(uartResponseTimeout), userInfo: nil, repeats: false)
        uartResponseDelegate = completionHandler
        uartData.sendData(data)
    }
    
    
    func didReceiveData(_ notification: Notification) {
        if let dataChunk = notification.userInfo?["dataChunk"] as? UartDataChunk {
            if let uartResponseDelegate = uartResponseDelegate {
                self.uartResponseDelegate = nil
                cancelUartResponseTimer()
                uartResponseDelegate(dataChunk.data as Data)
            }
        }
    }
    
    func uartResponseTimeout() {
        DLog("uartResponseTimeout")
        if let uartResponseDelegate = uartResponseDelegate {
            self.uartResponseDelegate = nil
            cancelUartResponseTimer()
            uartResponseDelegate(nil)
        }
    }
    
    fileprivate func cancelUartResponseTimer() {
        uartResponseTimer?.invalidate()
        uartResponseTimer = nil
    }
    
    
    // MARK: - Neopixel Commands
    fileprivate func checkNeopixelSketch() {
        
        // Send version command and check if returns a valid response
        DLog("Command: get Version")
        
        let command : [UInt8] = [0x56]      // V
        let data = Data(bytes: UnsafePointer<UInt8>(command), count: command.count)
        
        sendDataToUart(data) { [unowned self] responseData in
            var isSketchDetected = false
            if let data = responseData, let result = NSString(data:data, encoding: String.Encoding.utf8.rawValue) as? String {
                isSketchDetected = result.hasPrefix("Neopixel")
            }
            
            DLog("isNeopixelAvailable: \(isSketchDetected)")
            self.isSketchDetected = isSketchDetected
            
            self.delegate?.onNeopixelSketchDetected(isSketchDetected)
        }
    }
    
    func setupNeopixel(_ device: Board) {
        DLog("Command: Setup")
//        let pinNumber: UInt8 = 6       // TODO: ask user
        let pixelType: UInt16 = device.type
        
        let command : [UInt8] = [0x53, device.width, device.height, device.components, device.stride, /*pinNumber,*/ UInt8(pixelType), UInt8((UInt(pixelType) >> 8) & 0xff) ]            // Command: 'S'
        let data = Data(bytes: UnsafePointer<UInt8>(command), count: command.count)
        sendDataToUart(data) { [unowned self] responseData in
            var success = false
            if let data = responseData, let result = NSString(data:data, encoding: String.Encoding.utf8.rawValue) as? String {
                success = result.hasPrefix("OK")
            }
            
            DLog("setup success: \(success)")
            if success {
                self.board = device
            }
            self.delegate?.onNeopixelSetupFinished(success)
        }
    }
    
    func resetBoard() {
        board = nil
    }
    
    func setPixelColor(_ color: Color, x: UInt8, y: UInt8, completionHandler: ((Bool)->())? = nil) {
        DLog("Command: set Pixel")
        if board?.components == 3
        {
            let components = colorComponents(color)
            let command : [UInt8] = [0x50, x, y, components.red, components.green, components.blue ]      // Command: 'P'
            sendCommand(command, completionHandler: completionHandler)
        }
    }
    
    func clearBoard(_ color: Color, completionHandler: ((Bool)->())? = nil) {
        DLog("Command: Clear");
        
        if board?.components == 3
        {
            let components = colorComponents(color)
            let command : [UInt8] = [0x43, components.red, components.green, components.blue ]          // Command: 'C'
            sendCommand(command, completionHandler: completionHandler)
        }
    }
    
    func setBrighness(_ brightness: Float, completionHandler: ((Bool)->())? = nil) {
        DLog("Command: set Brightness: \(brightness)");
        
        let brightnessValue = UInt8(brightness*255)
        let command : [UInt8] = [0x42, brightnessValue ]          // Command: 'C'
        sendCommand(command, completionHandler: completionHandler)
    }
    
    fileprivate func colorComponents(_ color: Color) -> (red: UInt8, green: UInt8, blue: UInt8) {
        /*
        let ciColor = CIColor(CGColor: UIColor.redColor().CGColor)
        let r = UInt8(ciColor.red * 255)
        let g = UInt8(ciColor.green * 255)
        let b = UInt8(ciColor.blue * 255)
        DLog("r: \(ciColor.red), g: \(ciColor.green), b:\(ciColor.blue)")
        */
        
        let colorComponents = color.cgColor.components
        let r = UInt8((colorComponents?[0])! * 255)
        let g = UInt8((colorComponents?[1])! * 255)
        let b = UInt8((colorComponents?[2])! * 255)
        
        return (r, g, b)
    }
    
    
    func setImage(_ completionHandler: ((Bool)->())?) {
        DLog("Command: set Image");
    
        // todo: implement
        let width : UInt8 = 8
        let height : UInt8 = 4
        var command : [UInt8] = [0x49]                          // Command: 'I'
        
        let redPixel : [UInt8] = [32, 1, 1 ]
        let blackPixel : [UInt8] = [0, 0, 0 ]
        
        var imageData : [UInt8] = []
        let imageLength = width * height
        for i in 0..<imageLength {
            imageData.append(contentsOf: i%2==0 ? redPixel : blackPixel)
        }
        command.append(contentsOf: imageData)
        
        sendCommand(command, completionHandler: completionHandler)
    }
    
    fileprivate func sendCommand(_ command: [UInt8], completionHandler: ((Bool)->())? = nil) {
        let data = Data(bytes: UnsafePointer<UInt8>(command), count: command.count)
        sendCommand(data, completionHandler: completionHandler)
    }
    
    fileprivate func sendCommand(_ data: Data, completionHandler: ((Bool)->())? = nil) {
        guard board != nil else {
            DLog("setImage: unknown board")
            completionHandler?(false)
            return
        }
        
        sendDataToUart(data) { responseData in
            var success = false
            if let data = responseData, let result = NSString(data:data, encoding: String.Encoding.utf8.rawValue) as? String {
                success = result.hasPrefix("OK")
            }
            
            DLog("result: \(success)")
            completionHandler?(success)
        }
    }
}
