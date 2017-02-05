//
//  UartDataExport.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 10/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class UartDataExport {
    
    // MARK: - Export formatters
    static func dataAsText(_ dataBuffer: [UartDataChunk]) -> String? {
        // Compile all data
        let data = NSMutableData()
        for dataChunk in dataBuffer {
            data.append(dataChunk.data as Data)
        }
        
        var text: String?
        if (Preferences.uartIsInHexMode) {
            text = hexString(data as Data)
        }
        else {
            text = NSString(data:data as Data, encoding: String.Encoding.utf8.rawValue) as String?
        }
        
        return text
    }
    
    static func dataAsCsv(_ dataBuffer: [UartDataChunk])  -> String? {
        var text = "Timestamp,Mode,Data\r\n"        // csv Header
        
        let timestampDateFormatter = DateFormatter()
        timestampDateFormatter.setLocalizedDateFormatFromTemplate("HH:mm:ss:SSSS")
        
        for dataChunk in dataBuffer {
            let date = Date(timeIntervalSinceReferenceDate: dataChunk.timestamp)
            let dateString = timestampDateFormatter.string(from: date).replacingOccurrences(of: ",", with: ".")         //  comma messes with csv, so replace it by point
            let mode = dataChunk.mode == .rx ? "RX" : "TX"
            var dataString: String?
            if (Preferences.uartIsInHexMode) {
                dataString = hexString(dataChunk.data)
            }
            else {
                dataString = NSString(data:dataChunk.data as Data, encoding: String.Encoding.utf8.rawValue) as String?
            }
            if (dataString == nil) {
                dataString = ""
            }
            else {
                // Remove newline characters from data (it messes with the csv format and Excel wont recognize it)
                dataString = (dataString! as NSString).trimmingCharacters(in: CharacterSet.newlines)
            }
            
            text += "\(dateString),\(mode),\"\(dataString!)\"\r\n"
        }
        
        return text
    }
    
    static func dataAsJson(_ dataBuffer: [UartDataChunk])  -> String? {
        
        var jsonItemsDictionary : [AnyObject] = []
        
        for dataChunk in dataBuffer {
            let date = Date(timeIntervalSinceReferenceDate: dataChunk.timestamp)
            let unixDate = date.timeIntervalSince1970
            let mode = dataChunk.mode == .rx ? "RX" : "TX"
            var dataString: String?
            if (Preferences.uartIsInHexMode) {
                dataString = hexString(dataChunk.data)
            }
            else {
                dataString = NSString(data:dataChunk.data as Data, encoding: String.Encoding.utf8.rawValue) as String?
            }
            
            if let dataString = dataString {
                let jsonItemDictionary : [String : AnyObject] = [
                    "timestamp" : unixDate as AnyObject,
                    "mode" : mode as AnyObject,
                    "data" : dataString as AnyObject
                ]
                jsonItemsDictionary.append(jsonItemDictionary as AnyObject)
            }
        }
        
        let jsonRootDictionary: [String : AnyObject] = [
            "items": jsonItemsDictionary as AnyObject
        ]
        
        // Create Json NSData
        var data : Data?
        do {
            data = try JSONSerialization.data(withJSONObject: jsonRootDictionary, options: .prettyPrinted)
        } catch  {
            DLog("Error serializing json data")
        }
        
        // Create Json String
        var result : String?
        if let data = data {
            result = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String
        }
        
        return result
    }

    static func dataAsXml(_ dataBuffer: [UartDataChunk])  -> String? {
        
        #if os(OSX)
        let xmlRootElement = XMLElement(name: "uart")
        
        for dataChunk in dataBuffer {
            let date = Date(timeIntervalSinceReferenceDate: dataChunk.timestamp)
            let unixDate = date.timeIntervalSince1970
            let mode = dataChunk.mode == .rx ? "RX" : "TX"
            var dataString: String?
            if (Preferences.uartIsInHexMode) {
                dataString = hexString(dataChunk.data)
            }
            else {
                dataString = NSString(data:dataChunk.data as Data, encoding: String.Encoding.utf8.rawValue) as String?
            }
            
            if let dataString = dataString {
                
                let xmlItemElement = XMLElement(name: "item")
                xmlItemElement.addChild(XMLElement(name: "timestamp", stringValue:"\(unixDate)"))
                xmlItemElement.addChild(XMLElement(name: "mode", stringValue:mode))
                let dataNode = XMLElement(kind: .text, options: XMLNode.Options.nodeIsCDATA)
                dataNode.name = "data"
                dataNode.stringValue = dataString
                xmlItemElement.addChild(dataNode)
                
                xmlRootElement.addChild(xmlItemElement)
            }
        }
        
        let xml = XMLDocument(rootElement: xmlRootElement)
        let result = xml.xmlString(withOptions: Int(XMLNode.Options.nodePrettyPrint.rawValue))
        
        return result

        #else
            // TODO: implement for iOS
            
            
            return nil
            
        #endif
    }
    
    static func dataAsBinary(_ dataBuffer: [UartDataChunk]) -> Data? {
        guard dataBuffer.count > 0 else {
            return nil
        }
        
        let result = NSMutableData()
        for dataChunk in dataBuffer {
            result.append(dataChunk.data as Data)
        }
        
        return result as Data
    }
}
