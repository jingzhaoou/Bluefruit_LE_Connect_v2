//
//  NeopixelViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 10/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Cocoa

class NeopixelViewControllerOSX: NSViewController {

    // Config
    fileprivate static let kShouldAutoconnectToNeopixel = true
    
    // Constants
    fileprivate static let kUartTimeout = 5.0       // seconds
    
    // UI
    @IBOutlet weak var statusImageView: NSImageView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var sendButton: NSButton!
    
    // Bluetooth Uart
    fileprivate let uartData = UartManager.sharedInstance
    fileprivate var uartResponseDelegate : ((Data?)->Void)?
    fileprivate var uartResponseTimer : Timer?
    
    // Neopixel
    fileprivate var isNeopixelSketchAvailable : Bool?
    fileprivate var isSendingData = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    deinit {
        cancelUartResponseTimer()
    }

    
    func start() {
        DLog("neopixel start");
        let notificationCenter =  NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(NeopixelViewControllerOSX.didReceiveData(_:)), name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidReceiveData.rawValue), object: nil)
    }
    
    func stop() {
        DLog("neopixel stop");
        let notificationCenter =  NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidReceiveData.rawValue), object: nil)
        
        cancelUartResponseTimer()
    }
    
    func connectNeopixel() {
        start()
        if NeopixelViewControllerOSX.kShouldAutoconnectToNeopixel {
            self.checkNeopixelSketch()
        }

    }
    
    // MARK: Notifications
    func uartIsReady(_ notification: Notification) {
        DLog("Uart is ready")
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        
        DispatchQueue.main.async(execute: { [unowned self] in
             self.connectNeopixel()
            })
    }

    // MARK: - Neopixel Commands
    fileprivate func checkNeopixelSketch() {
        
        // Send version command and check if returns a valid response
        DLog("Ask Version...")
        let text = "V"
        if let data = text.data(using: String.Encoding.utf8) {
            sendDataToUart(data) { [unowned self] responseData in
                var isNeopixelSketchAvailable = false
                if let data = responseData, let result = NSString(data:data, encoding: String.Encoding.utf8.rawValue) as? String {
                    isNeopixelSketchAvailable = result.hasPrefix("Neopixel")
                }
 
                DLog("isNeopixelAvailable: \(isNeopixelSketchAvailable)")
                self.isNeopixelSketchAvailable = isNeopixelSketchAvailable
                
                DispatchQueue.main.async(execute: { [unowned self] in
                    self.updateUI()
                    });
            }
        }
    }
    
    fileprivate func updateUI() {

        var statusText = "Connecting..."
        statusImageView.image = NSImage(named: "NSStatusNone")
        if let isNeopixelSketchAvailable = isNeopixelSketchAvailable {
            statusText = isNeopixelSketchAvailable ? "Neopixel: Ready" : "Neopixel: Not available"
            
            statusImageView.image = NSImage(named: isNeopixelSketchAvailable ?"NSStatusAvailable":"NSImageNameStatusUnavailable")
        }

        statusLabel.stringValue = statusText
        sendButton.isEnabled = isNeopixelSketchAvailable == true && !isSendingData
    }
    
    
    // MARK: - Uart
    fileprivate func sendDataToUart(_ data: Data, completionHandler: @escaping (_ response: Data?)->Void) {
        guard uartResponseDelegate == nil && uartResponseTimer == nil else {
            DLog("sendDataToUart error: waiting for a previous response")
            return
        }
        
        uartResponseTimer = Timer.scheduledTimer(timeInterval: NeopixelViewControllerOSX.kUartTimeout, target: self, selector: #selector(NeopixelViewControllerOSX.uartResponseTimeout), userInfo: nil, repeats: false)
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
    
    // MARK: - Actions
    @IBAction func onClickSend(_ sender: AnyObject) {
        let data = NSMutableData()
        
        let width : UInt8 = 8
        let height : UInt8 = 4
        let command : [UInt8] = [0x44, width, height ]           // Command: 'D', Width: 8, Height: 8
        data.append(command, length: command.count)

        let redPixel : [UInt8] = [32, 1, 1 ]
        let blackPixel : [UInt8] = [0, 0, 0 ]
        
        var imageData : [UInt8] = []
        let imageLength = width * height
        for i in 0..<imageLength {
            imageData.append(contentsOf: i%2==0 ? redPixel : blackPixel)
        }
        data.append(imageData, length: imageData.count)
        
        //DLog("Send data: \(hexString(data))")
        /*
        if let message = NSString(data: data, encoding: NSUTF8StringEncoding) {
            DLog("Send data: \(message)")
        }
*/
        
        isSendingData = true
        sendDataToUart(data as Data) { [unowned self] responseData in
            var success = false
            if let data = responseData, let result = NSString(data:data, encoding: String.Encoding.utf8.rawValue) as? String {
                success = result.hasPrefix("OK")
                }
            
            DLog("configured: \(success)")
            self.isSendingData = false
            DispatchQueue.main.async(execute: { [unowned self] in
                self.updateUI()
                });
        }
    }
}

// MARK: - DetailTab
extension NeopixelViewControllerOSX : DetailTab {
    func tabWillAppear() {
        uartData.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
        
        if (uartData.isReady()) {
            connectNeopixel()
        }
        else {
            DLog("Wait for uart to be ready to start PinIO setup")
            
            let notificationCenter =  NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(NeopixelViewControllerOSX.uartIsReady(_:)), name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        }
        
        updateUI()
    }
    
    func tabWillDissapear() {
        stop()
    }
    
    func tabReset() {
    }
}
