//
//  PinIOModuleViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PinIOModuleViewController: ModuleViewController {

    fileprivate let pinIO = PinIOModuleManager()
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!
    fileprivate var tableRowOpen: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup table
        baseTableView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0)      // extend below navigation inset fix
  
        // Init
        pinIO.delegate = self
    
        // Start Uart Manager
        UartManager.sharedInstance.blePeripheral = BleManager.sharedInstance.blePeripheralConnected       // Note: this will start the service discovery

        if (UartManager.sharedInstance.isReady()) {
            setupFirmata()
        }
        else {
            DLog("Wait for uart to be ready to start PinIO setup")

            let notificationCenter =  NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(PinIOModuleViewController.uartIsReady(_:)), name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        }
    }

    func uartIsReady(_ notification: Notification) {
        DLog("Uart is ready")
        let notificationCenter =  NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: UartManager.UartNotifications.DidBecomeReady.rawValue), object: nil)
        
        DispatchQueue.main.async(execute: { [unowned self] in
            self.setupFirmata()
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
        DLog("PinIO viewWillAppear")
        pinIO.start()
        
        if pinIO.pins.count == 0 && !pinIO.isQueryingCapabilities() {
            startQueryCapabilitiesProcess()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    
        // if a dialog is being shown, dismiss it. For example: when querying capabilities but a didmodifyservices callback is received and pinio is removed from the tabbar
        if let presentedViewController = presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        DLog("PinIO viewWillDisappear")
        pinIO.stop()
    }
    
    fileprivate func setupFirmata() {
        // Reset Firmata and query capabilities
        pinIO.reset()
        tableRowOpen = nil
        baseTableView.reloadData()
        if isViewLoaded && view.window != nil {     // if is visible
            startQueryCapabilitiesProcess()
        }
    }
    
    fileprivate func startQueryCapabilitiesProcess() {
        guard !pinIO.isQueryingCapabilities() else {
            DLog("error: queryCapabilities called while querying capabilities")
            return
        }

        // Show dialog
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: nil, message: localizationManager.localizedString("pinio_capabilityquery_querying_title"), preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: localizationManager.localizedString("dialog_cancel"), style: .cancel, handler: { [weak self] (_) -> Void in
            self?.pinIO.endPinQuery(true)
            }))

        self.present(alertController, animated: true) {[weak self] () -> Void in
            // Query Capabilities
            self?.pinIO.queryCapabilities()
        }
    }
    
    func defaultCapabilitiesAssumedDialog() {
        
        DLog("QueryCapabilities not found")
        let localizationManager = LocalizationManager.sharedInstance
        let alertController = UIAlertController(title: localizationManager.localizedString("pinio_capabilityquery_expired_title"), message: localizationManager.localizedString("pinio_capabilityquery_expired_message"), preferredStyle: .alert)
        let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler:{ (_) -> Void in
        })
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - Actions
    @IBAction func onClickQuery(_ sender: AnyObject) {
        setupFirmata()
    }
    
    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.sharedInstance
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("pinio_help_text"), title: localizationManager.localizedString("pinio_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender
        
        present(helpNavigationController, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension PinIOModuleViewController : UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pinIO.pins.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return LocalizationManager.sharedInstance.localizedString("pinio_pins_header")
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "PinCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let pin = pinIO.pins[indexPath.row]
        let pinCell = cell as! PinIOTableViewCell
        pinCell.setPin(pin)

        pinCell.tag = indexPath.row
        pinCell.delegate = self
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let tableRowOpen = tableRowOpen, indexPath.row == tableRowOpen {
            let pinOpen = pinIO.pins[tableRowOpen]
            return pinOpen.mode == .input || pinOpen.mode == .analog ? 100 : 160
        }
        else {
            return 44
        }
    }
}

// MARK:  UITableViewDelegate
extension PinIOModuleViewController : UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK:  PinIoTableViewCellDelegate
extension PinIOModuleViewController : PinIoTableViewCellDelegate {
    func onPinToggleCell(_ pinIndex: Int) {
        // Change open row
        tableRowOpen = pinIndex == tableRowOpen ? nil: pinIndex
 
        // Animate changes
        baseTableView.beginUpdates()
        baseTableView.endUpdates()
    }
    func onPinModeChanged(_ mode: PinIOModuleManager.PinData.Mode, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setControlMode(pin, mode: mode)
        
        baseTableView.reloadRows(at: [IndexPath(row: pinIndex, section: 0)], with: .none)
    }
    func onPinDigitalValueChanged(_ value: PinIOModuleManager.PinData.DigitalValue, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        pinIO.setDigitalValue(pin, value: value)
        
        baseTableView.reloadRows(at: [IndexPath(row: pinIndex, section: 0)], with: .none)
    }
    func onPinAnalogValueChanged(_ value: Float, pinIndex: Int) {
        let pin = pinIO.pins[pinIndex]
        if pinIO.setPMWValue(pin, value: Int(value)) {
            baseTableView.reloadRows(at: [IndexPath(row: pinIndex, section: 0)], with: .none)
        }
    }
}

extension PinIOModuleViewController: PinIOModuleManagerDelegate {
    func onPinIODidEndPinQuery(_ isDefaultConfigurationAssumed: Bool) {
        DispatchQueue.main.async(execute: { [unowned self] in
            self.baseTableView.reloadData()
            
            self.presentedViewController?.dismiss(animated: true, completion: { () -> Void in
                if isDefaultConfigurationAssumed {
                    self.defaultCapabilitiesAssumedDialog()
                }
            })
            
            })
    }
    
    func onPinIODidReceivePinState() {
        DispatchQueue.main.async(execute: { [unowned self] in
            
            self.baseTableView.reloadData()
  
            })
    }
}
