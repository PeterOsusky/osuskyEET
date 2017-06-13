//
//  SettingsViewController.swift
//  BLEDemo
//
//  Created by Peter on 08/05/2017.
//  Copyright © 2017 Peter Osusky. All rights reserved.
//

import UIKit
import CoreBluetooth


class SettingsViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    var manager:CBCentralManager? = nil
    var mainPeripheral:CBPeripheral? = nil
    var mainCharacteristic:CBCharacteristic? = nil
    var parentView:ViewController? = nil
    
    
    let BLEService = "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2"
    let BLECharacteristic = "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F"
    
    
    @IBOutlet var nameLabel: UITextField!
    @IBOutlet var cityLabel: UITextField!
    @IBOutlet var DIC: UITextField!
    @IBOutlet var premises: UITextField!
    @IBOutlet var cashReg: UITextField!
    @IBOutlet var certPass: UITextField!
    @IBOutlet var ICO: UITextField!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet var certName: UITextField!
    
    
    @IBAction func saveData(_ sender: Any) {
        try? getData().taxFormData.name = nameLabel.text
        try? getData().taxFormData.city = cityLabel.text
        try? getData().eetData.cashRegisterID = cashReg.text!
        try? getData().eetData.premisesID = premises.text
        try? getData().taxFormData.pass = certPass.text
        try? getData().taxFormData.ICO = ICO.text
        try? getData().taxFormData.DIC = DIC.text
        try? getData().taxFormData.certificateName = certName.text
        parentView?.getAlert(title: "", message: "Data boli ulozene")
    }
    
    func dismissKeyboard(){
        view.endEditing(true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager = CBCentralManager(delegate: self, queue: nil);
        customiseNavigationBar()
        let tap: UIGestureRecognizer = UITapGestureRecognizer(target: self, action: "dismissKeyboard")
        view.addGestureRecognizer(tap)
        setData()

    }
    
    func setData(){
        try? certPass.text = getData().taxFormData.pass
        try? nameLabel.text = getData().taxFormData.name
        try? cityLabel.text = getData().taxFormData.city
        try? cashReg.text = getData().eetData.cashRegisterID
        try? premises.text = getData().eetData.premisesID
        try? ICO.text = getData().taxFormData.ICO
        try? DIC.text = getData().taxFormData.DIC
        try? certName.text = getData().taxFormData.certificateName
}
    

    
    func customiseNavigationBar () {
        
        self.navigationItem.rightBarButtonItem = nil
        
        let rightButton = UIButton()
        
        if (mainPeripheral == nil) {
            rightButton.setTitle("Tisk", for: [])
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 60, height: 30))
            rightButton.addTarget(self, action: #selector(self.scanButtonPressed), for: .touchUpInside)
        } else {
            rightButton.setTitle("Odpoj", for: [])
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 100, height: 30))
            rightButton.addTarget(self, action: #selector(self.disconnectButtonPressed), for: .touchUpInside)
        }
        
        let rightBarButton = UIBarButtonItem()
        rightBarButton.customView = rightButton
        self.navigationItem.rightBarButtonItem = rightBarButton
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if (segue.identifier == "scan-segue") {
            let scanController : ScanTableViewController = segue.destination as! ScanTableViewController
            
            //set the manager's delegate to the scan view so it can call relevant connection methods
            manager?.delegate = scanController
            scanController.manager = manager
            scanController.parentView = self
        }
        
    }
    
    // MARK: Button Methods
    func scanButtonPressed() {
        performSegue(withIdentifier: "scan-segue", sender: nil)
    }
    
    func disconnectButtonPressed() {
        //this will call didDisconnectPeripheral, but if any other apps are using the device it will not immediately disconnect
        manager?.cancelPeripheralConnection(mainPeripheral!)
    }
    
    
    
    
    // MARK: - CBCentralManagerDelegate Methods    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        mainPeripheral = nil
        customiseNavigationBar()
        print("Disconnected1" + peripheral.name!)
    }
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }
    
    // MARK: CBPeripheralDelegate Methods
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            if (service.uuid.uuidString == BLEService) {
                peripheral.discoverCharacteristics(nil, for: service)
                print("found print service")
            }
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if (service.uuid.uuidString == BLEService) {
            for characteristic in service.characteristics! {                
                if (characteristic.uuid.uuidString == BLECharacteristic) {
                    mainCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    parentView?.model?.mainCharacteristic = mainCharacteristic
                    parentView?.model?.mainPeripheral = mainPeripheral
                }
                
            }
            
        }
        
    }
    
    func getData()throws -> DataModel{
        return (parentView?.model?.account)!
    }
    
    
        
    }
    


