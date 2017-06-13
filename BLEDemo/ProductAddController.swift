//
//  ProductAddController.swift
//  BLEDemo
//
//  Created by Peter on 08/05/2017.
//  Copyright © 2017 Peter Osusky. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class ProductAddController: UIViewController {    
    
    var parentView:ProductViewController? = nil
    
    @IBOutlet var name: UITextField!
    @IBOutlet var price: UITextField!
    @IBOutlet var vat: UITextField!
    @IBOutlet var add: UIButton!
    
    @IBAction func addProduct(_ sender: Any) {
        if (name.text == "" || price.text == "" || vat.text == ""){
            parentView?.parentView?.getAlert(title: "Chyba", message: "Informace nejsou kompletni")
        }else{
            parentView?.parentView?.model?.addProduct(name: name.text!, price: price.text!, vat: vat.text!)
            name.text = ""
            price.text = ""
            vat.text = ""
            parentView?.parentView?.getAlert(title: "", message: "Zboží přidáno")
            parentView?.tableView.reloadData()
        }
    }
    

    
    
}
