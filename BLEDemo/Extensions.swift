//
//  Extensions.swift
//  BLEDemo
//
//  Created by Peter on 08/05/2017.
//  Copyright © 2017 Peter Osusky. All rights reserved.
//

import Foundation
import KissXML
import XUCore

public extension NSXMLNode {
    
    
    public var integerValue: Int {
        return self.stringValue?.integerValue ?? 0
    }
    
    
    
    public func firstNode(onXPath xpath: String) -> NSXMLNode? {
        do {
            return try self.nodes(forXPath: xpath).first
        }catch{
            return nil}
    }
    
    public func integerValue(ofFirstNodeOnXPath xpath: String) -> Int {
        return self.integerValue(ofFirstNodeOnXPaths: [xpath])
    }
    public func integerValue(ofFirstNodeOnXPaths xpaths: [String]) -> Int {
        return self.stringValue(ofFirstNodeOnXPaths: xpaths)?.integerValue ?? 0
    }
    public func lastNode(onXPath xpath: String) -> NSXMLNode? {
        do {
            return try self.nodes(forXPath: xpath).last
        }catch{
            return nil}
    }
    
    public func stringValue(ofFirstNodeOnXPath xpath: String) -> String? {
        return self.firstNode(onXPath: xpath)?.stringValue
    }
    public func stringValue(ofFirstNodeOnXPaths xpaths: [String]) -> String? {
        for path in xpaths {
            if let result = self.stringValue(ofFirstNodeOnXPath: path) {
                if result.characters.count > 0 {
                    return result
                }
            }
        }
        return nil
    }
    public func stringValue(ofLastNodeOnXPath xpath: String) -> String? {
        return self.lastNode(onXPath: xpath)?.stringValue
    }
    public func integerValue(ofAttributeNamed attributeName: String) -> Int {
        return 0
    }
    public func stringValue(ofAttributeNamed attributeName: String) -> String? {
        return nil
    }
    
}


public extension NSXMLElement {
    
    @discardableResult
    public func addAttribute(named name: String, withStringValue value: String) -> NSXMLNode {
        do {
            let node = try NSXMLNode()
            node.name = name
            node.stringValue = value
            self.addAttribute(node)
            return node
        }catch{
            print(error)}
    }
    
    
    public override func integerValue(ofAttributeNamed attributeName: String) -> Int {
        return self.attribute(forName: attributeName)?.integerValue ?? 0
    }
    public override func stringValue(ofAttributeNamed attributeName: String) -> String? {
        return self.attribute(forName: attributeName)?.stringValue
    }
}

public extension NSXMLElement {
    
    var canonicalXMLString: String {
        var result = "<\(self.name!)"
        if var attributes = self.attributes, !attributes.isEmpty {
            attributes.sort(by: {
                let name1 = $0.name!
                let name2 = $1.name!
                if name1.hasPrefix("xmlns") {
                    if name2.hasPrefix("xmlns") {
                        return name1 < name2
                    }
                    
                    return true
                }
                
                if name2.hasPrefix("xmlns") {
                    return false
                }
                
                return name1 < name2
            })
            
            result += " "
            result += attributes.map({ $0.xmlString }).joined(separator: " ")
        }
        result += ">"
        
        if let children = self.children?.flatMap({ $0 as? NSXMLElement }), !children.isEmpty {
            result += children.map({ $0.canonicalXMLString }).joined()
        } else if let stringValue = self.stringValue {
            result += stringValue
        }
        
        result += "</\(self.name!)>"
        return result
    }
    
}

public extension NSXMLDocument {
    
    public convenience init?(string: String, andOptions mask: Int) {
        try? self.init(xmlString: string, options: UInt(mask))
    }
    
}


public extension Dictionary where Key: ExpressibleByStringLiteral, Value: Any {
    
    public func xmlElement(withName elementName: String) -> NSXMLElement {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        
        let element = NSXMLElement(name: elementName)
        for (k, value) in self {
            let key = String(describing: k)
            if let val =  value as? String {
                element.addChild(NSXMLElement(name: key, stringValue: val))
            } else if let val = value as? NSDecimalNumber {
                element.addChild(NSXMLElement(name: key, stringValue: String(format: "%0.4f", val)))
            } else if let val = value as? NSNumber {
                element.addChild(NSXMLElement(name: key, stringValue: "\(val.stringValue)"))
            } else if let val = value as? Date {
                element.addChild(NSXMLElement(name: key, stringValue: formatter.string(from: val)))
            } else if let val = value as? XUJSONDictionary {
                if val.isEmpty {
                    continue
                }
                element.addChild(val.xmlElement(withName: key))
            } else if let val = value as? [Dictionary] {
                if val.isEmpty {
                    continue
                }
                
                for obj in val {
                    element.addChild(obj.xmlElement(withName: key))
                }
            } else {
                fatalError("Dictionary contains a value of unsupported type.")
            }
        }
        return element
    }
    
}



public extension XUDownloadCenter{
    
    public func downloadXMLDocument(at url: URL!, withRequestModifier modifier: URLRequestModifier? = nil) -> NSXMLDocument? {
        guard let source = self.downloadWebPage(at: url, withRequestModifier: modifier) else {
            return nil // Error already set.
        }
        
        let doc = try? NSXMLDocument(xmlString: source, options: 0)
        if doc == nil {
            if self.logTraffic {
                XULog("[\(self.owner.name)] - failed to parse XML document \(source)")
            }
        }
        return doc
    }
}

    public extension Double {
        
        func roundTo()->Double{
            let divisor = pow(10.0, Double(2))
            return (self * divisor).rounded() / divisor
        }        
    }
