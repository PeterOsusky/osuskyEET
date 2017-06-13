//
//  ProductViewController.swift
//  BLEDemo
//
//  Created by Peter on 08/05/2017.
//  Copyright © 2017 Peter Osusky. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class ProductViewController: UITableViewController {
    
    var parentView:ViewController? = nil
    var products = [Product]()
    var list: List? = nil


    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return products.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "productCell", for: indexPath) as! ProductCellController
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
        products = try! DatabaseController.getContext().fetch(fetchRequest) as! [Product]
        
        let product = products[indexPath.row]
        cell.nameLabel?.text = product.name
        cell.priceLabel?.text =  product.price
        cell.vatLabel?.text = product.vat
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        products[indexPath.row].addToList(list!)
        DatabaseController.saveContext()
        parentView?.getAlert(title: "", message: "Zbozi pridano na uctenku")
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if (segue.identifier == "productAdd-segue") {
            let productAddController : ProductAddController = segue.destination as! ProductAddController
            productAddController.parentView = self
            }
        }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.reloadData()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
        products = try! DatabaseController.getContext().fetch(fetchRequest) as! [Product]
        self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let context = DatabaseController.getContext()
            context.delete(products[indexPath.row])
            DatabaseController.saveContext()
            products.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }



}
