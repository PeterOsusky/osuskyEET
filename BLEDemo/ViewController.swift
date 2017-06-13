//
//  MainModel.swift
//  BLEDemo
//
//  Created by Peter on 08/05/2017.
//  Copyright © 2017 Peter Osusky. All rights reserved.
//

import UIKit
import XUCore
import KissXML
import SwiftyRSA
import Foundation
import Security
import CoreBluetooth
import CoreData

class ViewController: UIViewController, CBCentralManagerDelegate, UITableViewDelegate, UITableViewDataSource {
    var manager:CBCentralManager? = nil
    var mainPeripheral:CBPeripheral? = nil
    var mainCharacteristic:CBCharacteristic? = nil
    var model: MainModel? = nil
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }
        
    
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var listTable: UITableView!
    @IBOutlet var custBut: UIButton!
    @IBAction func printText(_ sender: Any) {
    }
    
    
    //let account = DataModel()
    @IBAction func start(_ sender: Any) {
        model?.sendPayment()
        print("send")
        self.listTable.reloadData()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        model = MainModel()
        //self.listTable.reloadData()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "List")
        model?.list = try! DatabaseController.getContext().fetch(fetchRequest) as! [List]
        model?.viewController = self
        if model?.list.count == 0{
            let listNil: List = NSEntityDescription.insertNewObject(forEntityName: "List", into: DatabaseController.getContext()) as! List
            model?.list.append(listNil)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.listTable.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if (segue.identifier == "main-segue") {
            let mainController : SettingsViewController = segue.destination as! SettingsViewController
            manager?.delegate = mainController
            mainController.manager = manager
            mainController.parentView = self
        }else if (segue.identifier == "product-segue"){
            let productController : ProductViewController = segue.destination as! ProductViewController
            productController.parentView = self
            productController.list = model?.list[0]
        
        }
        
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return (model?.list[0].product?.allObjects.count)!
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "listCell", for: indexPath) as! ListCellController
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "List")
        model?.list = try! DatabaseController.getContext().fetch(fetchRequest) as! [List]
        let list0 = model?.list[0]
        let products = list0?.product?.allObjects as! [Product]
        let product = products[indexPath.row]
        cell.name?.text = product.name
        cell.price.text =  product.price
        cell.qty.text = String(format: "%0.0f", product.quantity!.doubleValue)
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let list0 = model?.list[0]
            let products = list0?.product?.allObjects as! [Product]
            let product = products[indexPath.row]
            product.removeFromList(list0!)
            product.quantity = 1
            DatabaseController.saveContext()
            tableView.deleteRows(at: [indexPath], with: .fade)
            self.listTable.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let products = model?.getProducts(list: (model?.list)!)
        let product = products?[indexPath.row]
        product?.setQuantity()
        DatabaseController.saveContext()
        self.listTable.reloadData()
    }
    
    func getAlert(title: String, message: String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}
