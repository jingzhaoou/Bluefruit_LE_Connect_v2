//
//  NSDataConversions.swift
//  bluefruitconnect
//
//  Created by Antonio García on 26/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

/*
// http://stackoverflow.com/questions/1305225/best-way-to-serialize-a-nsdata-into-an-hexadeximal-string
func hexString(data:NSData)->String{
    
    if data.length > 0 {
        let  hexChars = Array("0123456789abcdef".utf8) as [UInt8];
        let buf = UnsafeBufferPointer<UInt8>(start: UnsafePointer(data.bytes), count: data.length);
        var output = [UInt8](count: data.length*2 + 1, repeatedValue: 0);
        var ix:Int = 0;
        for b in buf {
            let hi  = Int((b & 0xf0) >> 4);
            let low = Int(b & 0x0f);
            output[ix++] = hexChars[ hi];
            output[ix++] = hexChars[low];
        }
        let result = String.fromCString(UnsafePointer(output))!;
        return result;
    }
    return "";
}

func hexString(text:String)->String{
    if let data = text.dataUsingEncoding(NSUTF8StringEncoding) {
        return hexString(data)
    }
    else {
        return ""
    }
}
*/

// MARK: - Strings
func hexString(_ data: Data) -> String {
    var bytes = [UInt8](repeating: 0, count: data.count)
    (data as NSData).getBytes(&bytes, length: data.count)
    
    let hexString = NSMutableString()
    for byte in bytes {
        hexString.appendFormat("%02X ", UInt(byte))
    }
    
    return NSString(string: hexString) as String
}


