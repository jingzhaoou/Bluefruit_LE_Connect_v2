//
//  BleUUIDNames.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 15/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation


class BleUUIDNames {
    
    // Manager
    static let sharedInstance = BleUUIDNames()

    // Data
    fileprivate var gattUUIds : [String : String]?

    init() {
        // Read known UUIDs
        let path = Bundle.main.path(forResource: "GattUUIDs", ofType: "plist")!
        gattUUIds = NSDictionary(contentsOfFile: path) as? [String : String]

    }
    
    func nameForUUID(_ uuid: String) -> String? {
        return gattUUIds?[uuid]
    }
}
