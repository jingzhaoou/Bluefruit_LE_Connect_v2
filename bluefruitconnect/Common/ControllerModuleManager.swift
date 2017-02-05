//
//  ControllerModuleManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreLocation
import MSWeakTimer

// TODO: add support for OSX
#if os(OSX)
#else
    import CoreMotion
#endif

protocol ControllerModuleManagerDelegate: class {
    func onControllerUartIsReady()
}

class ControllerModuleManager : NSObject {
    
    enum ControllerType : Int {
        case attitude = 0
        case accelerometer
        case gyroscope
        case magnetometer
        case location
    }
    static let numSensors = 5
    
    static fileprivate let prefixes = ["!Q", "!A", "!G", "!M", "!L"];     // same order that ControllerType
    
    // Data
    weak var delegate: ControllerModuleManagerDelegate?
    
    var isSensorEnabled = [Bool](repeating: false, count: ControllerModuleManager.numSensors)

    #if os(OSX)
    #else
    fileprivate let coreMotionManager = CMMotionManager()
    #endif
    fileprivate let locationManager = CLLocationManager()
    fileprivate var lastKnownLocation :CLLocation?
    
    fileprivate var pollTimer : MSWeakTimer?
    fileprivate var timerHandler : (()->())?
    
    fileprivate let uartManager = UartManager.sharedInstance
    
    fileprivate var pollInterval: TimeInterval = 1        // in seconds
    
    override init() {
        super.init()
        
        // Setup Location Manager
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.delegate = self
    }
    
    deinit {
        locationManager.delegate = nil
        // Disable everthing
        for i in 0..<ControllerModuleManager.numSensors {
            setSensorEnabled(false, index: i)
        }
    }
    
    func start(_ pollInterval: TimeInterval, handler:(()->())?) {
        self.pollInterval = pollInterval
        self.timerHandler = handler
        
        // Start Uart Manager
        UartManager.sharedInstance.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery
        
        // Notifications
        let notificationCenter =  NotificationCenter.default
        if !uartManager.isReady() {
            notificationCenter.addObserver(self, selector: #selector(uartIsReady(_:)), name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        }
        else {
            delegate?.onControllerUartIsReady()
            startUpdatingData()
        }
        
    }
    
    func stop() {
        let notificationCenter =  NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        
        stopUpdatingData()
    }
    
    // MARK: Notifications
    func uartIsReady(_ notification: Notification) {
        DLog("Uart is ready")
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        
        delegate?.onControllerUartIsReady()
        startUpdatingData()
    }
    

    // MARK: -
    fileprivate func startUpdatingData() {
        pollTimer = MSWeakTimer.scheduledTimer(withTimeInterval: pollInterval, target: self, selector: #selector(updateSensors), userInfo: nil, repeats: true, dispatchQueue: DispatchQueue.main)
    }
    
    fileprivate func stopUpdatingData() {
        timerHandler = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    func updateSensors() {
        timerHandler?()
        
        for i in 0..<ControllerModuleManager.numSensors {
            if isSensorEnabled(i) {
                if let sensorData = getSensorData(i) {
                    
                    let data = NSMutableData()
                    let prefixData = ControllerModuleManager.prefixes[i].data(using: String.Encoding.utf8)!
                    data.append(prefixData)
                    
                    for value in sensorData {
                        var floatValue = Float(value)
                        data.append(&floatValue, length: MemoryLayout<Float>.size)
                    }
                    
                    uartManager.sendDataWithCrc(data as Data)
                }
            }
        }
    }
    
    func isSensorEnabled(_ index: Int) -> Bool {
        return isSensorEnabled[index]
    }
    
    func getSensorData(_ index: Int) -> [Double]? {
        guard isSensorEnabled(index) else {
            return nil
        }
        
        switch ControllerType(rawValue: index)! {
        case .attitude:
            if let attitude = coreMotionManager.deviceMotion?.attitude {
                return [attitude.quaternion.x, attitude.quaternion.y, attitude.quaternion.z, attitude.quaternion.w]
            }
        case .accelerometer:
            if let acceleration = coreMotionManager.accelerometerData?.acceleration {
                return [acceleration.x, acceleration.y, acceleration.z]
            }
        case .gyroscope:
            if let rotation = coreMotionManager.gyroData?.rotationRate {
                return [rotation.x, rotation.y, rotation.z]
            }
        case .magnetometer:
            if let magneticField = coreMotionManager.magnetometerData?.magneticField {
                return [magneticField.x, magneticField.y, magneticField.z]
            }
        case .location:
            if let location = lastKnownLocation {
                return [location.coordinate.latitude, location.coordinate.longitude, location.altitude]
            }
        }
        
        return nil
    }
    
    func setSensorEnabled(_ enabled: Bool, index: Int) -> String? {
        isSensorEnabled[index] = enabled
        
        var errorString : String?
        switch ControllerType(rawValue: index)! {
        case .attitude:
            if enabled {
                coreMotionManager.startDeviceMotionUpdates()
            }
            else {
                coreMotionManager.stopDeviceMotionUpdates()
            }

        case .accelerometer:
            if enabled {
                coreMotionManager.startAccelerometerUpdates()
            }
            else {
                coreMotionManager.stopAccelerometerUpdates()
            }
        case .gyroscope:
            if enabled {
                coreMotionManager.startGyroUpdates()
            }
            else {
                coreMotionManager.stopGyroUpdates()
            }
            
        case .magnetometer:
            if enabled {
                coreMotionManager.startMagnetometerUpdates()
            }
            else {
                coreMotionManager.stopMagnetometerUpdates()
            }
            
        case .location:
            if enabled {
                if CLLocationManager.locationServicesEnabled() {
                    let authorizationStatus = CLLocationManager.authorizationStatus()
                    switch authorizationStatus {
                    case .notDetermined:
                        locationManager.requestWhenInUseAuthorization()
                    case .denied:
                        errorString = LocalizationManager.sharedInstance.localizedString("controller_sensor_location_denied")
                    case .restricted:
                        errorString = LocalizationManager.sharedInstance.localizedString("controller_sensor_location_restricted")
                    default:
                        locationManager.startUpdatingLocation()
                    }
                }
                else {      // Location services disabled
                    DLog("Location services disabled")
                    errorString = LocalizationManager.sharedInstance.localizedString("controller_sensor_location_disabled")
                }
            }
            else {
                locationManager.stopUpdatingLocation()
            }

        }
        
        return errorString
    }
}

extension ControllerModuleManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnownLocation = locations.last
    }
}
