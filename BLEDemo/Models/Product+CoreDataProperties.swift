//
//  Product+CoreDataProperties.swift
//  
//
//  Created by Peter on 21/04/2017.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Product {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Product> {
        return NSFetchRequest<Product>(entityName: "Product");
    }

    @NSManaged public var name: String?
    @NSManaged public var price: String?
    @NSManaged public var vat: String?
    @NSManaged public var quantity: NSDecimalNumber?
    @NSManaged public var list: NSSet?
    
    public func setQuantity(){
        self.quantity = (((self.quantity! as NSDecimalNumber) as Decimal) + ((1 as NSDecimalNumber) as Decimal)) as NSDecimalNumber
    }
    
}

// MARK: Generated accessors for list
extension Product {

    @objc(addListObject:)
    @NSManaged public func addToList(_ value: List)

    @objc(removeListObject:)
    @NSManaged public func removeFromList(_ value: List)

    @objc(addList:)
    @NSManaged public func addToList(_ values: NSSet)

    @objc(removeList:)
    @NSManaged public func removeFromList(_ values: NSSet)

}
