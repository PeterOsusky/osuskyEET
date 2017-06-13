//
//  MainModel.swift
//  BLEDemo
//
//  Created by Peter on 08/05/2017.
//  Copyright © 2017 Peter Osusky. All rights reserved.
//

import XUCore
import KissXML
import SwiftyRSA
import Foundation
import Security
import CoreBluetooth
import CoreData
import UIKit

class MainModel: NSObject, CBCentralManagerDelegate{
    
    var manager:CBCentralManager? = nil
    var mainPeripheral:CBPeripheral? = nil
    var mainCharacteristic:CBCharacteristic? = nil
    var list = [List]()
    var totalAmount = NSDecimalNumber.zero
    var vat1Amount = NSDecimalNumber.zero
    var vat2Amount = NSDecimalNumber.zero
    var vat3Amount = NSDecimalNumber.zero
    var vat4Amount = NSDecimalNumber.zero
    var rawData: Data? = nil
    var cisloUctenky = ""
    var viewController:ViewController? = nil
    
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }
    
    
    let account = DataModel()
    public func sendPayment() {
        
        getProductsPrice(products: getProducts(list: list))
        
        let vat1 = ComunicationModel.PaymentCommand.PaymentAmount.VATPayment(vatExclusive: vat1Amount * -1, vat: vat1Amount * -0.21)
        let vat2 = ComunicationModel.PaymentCommand.PaymentAmount.VATPayment(vatExclusive: vat2Amount * -1, vat: vat2Amount * -0.15)
        let vat3 = ComunicationModel.PaymentCommand.PaymentAmount.VATPayment(vatExclusive: vat3Amount * -1, vat: vat3Amount * -0.10)
        
        
        let amount = ComunicationModel.PaymentCommand.PaymentAmount(total: totalAmount, baseRateVATPayment: vat1, loweredRateVATPayment: vat2, ultraLoweredVat: vat3)
        
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMyyyy"
        let day = formatter.string(from: date)
        formatter.dateFormat = "HHmmss"
        let time = formatter.string(from: date)
        
        if ((account.eetData.premisesID! != "")&&(account.eetData.cashRegisterID! != "")) {
            cisloUctenky = "\(account.eetData.premisesID!)\(account.eetData.cashRegisterID!)\(day)\(time)"
        }else{
            viewController?.getAlert(title: "Chyba", message: "Neni zadana provozovna nebo pokladna")
        }
        
        
        do{
            let fileManager = FileManager.default
            let documentsDirectory = FileManager.SearchPathDirectory.documentDirectory
            let userDomain = FileManager.SearchPathDomainMask.userDomainMask
            let documentsURL = try! NSSearchPathForDirectoriesInDomains(documentsDirectory, userDomain, true)
            let documentsDirectoryFirst = documentsURL.first
            let url = NSURL(fileURLWithPath: documentsDirectoryFirst!)
            
            
            let certificateURL = URL(fileURLWithPath: documentsDirectoryFirst!).appendingPathComponent("\(self.account.taxFormData.certificateName!).p12")
            let certificatePath = url.appendingPathComponent("\(self.account.taxFormData.certificateName!).p12")?.path
            
            if fileManager.fileExists(atPath: certificatePath!){
                self.rawData = try! Data(contentsOf: certificateURL)}
            else{
                viewController?.getAlert(title: "Certifikat", message: "Certifikat nenalezen")
            }
            
            if try (checkData(account: account)){
                
                let paymentCommand = ComunicationModel.PaymentCommand(documentNumber: cisloUctenky, paymentAmount: amount, transactionDate: Date())
                
                account.eetData.certificate = try DataModel.EET.Certificate.init(rawData: rawData!, password: account.taxFormData.pass!)
                
                let communicator = try ComunicationModel(localeSpecificData: self.account, vatRegistrationID: "\(self.account.taxFormData.DIC!)")
                
                let response = try communicator.sendPayment(paymentCommand, validatingOnly: false)
                print(response)
                
                switch response {
                    
                case .success(let payload):
                    printPayload(payload: payload, command: paymentCommand)
                    clearListData()
                    viewController?.getAlert(title: "", message: "Platba odeslana")
                    
                case .error(let error):
                    let errStr = error.description
                    viewController?.getAlert(title: "", message: errStr)
                    print(errStr)
                }
            }
        }
        catch let err as ComunicationModel.InitializationError {
            let errStr = err.localizedDescription
            viewController?.getAlert(title: "", message: errStr)
            print(errStr)
        }
            
        catch let err as ComunicationModel.SendingError {
            let errStr = err.localizedDescription
            viewController?.getAlert(title: "", message: errStr)
            print(errStr)
        }
            
        catch {
            viewController?.getAlert(title: "Neznama chyba", message: "Zkontrolujte spravnost udaju v nastaveni")
        }
    }
    
    func printPayload(payload: ComunicationModel.PaymentResponse.Payload, command: ComunicationModel.PaymentCommand){
        
        let date = command.transactionDate
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let day = formatter.string(from: date)
        formatter.dateFormat = "HH:mm:ss"
        let time = formatter.string(from: date)
        let price = String(format: "%0.2f", totalAmount.doubleValue)
        let totalVat = vat4Amount+vat3Amount+vat2Amount+vat1Amount
        let vat = String(format: "%0.2f", totalVat.doubleValue)
        printLine(text: "\n")
        printLine(text: account.taxFormData.name!)
        printLine(text: "\n")
        printLine(text: account.taxFormData.city!)
        printLine(text: "\n")
        printLine(text: "ICO: ")
        printLine(text: account.taxFormData.ICO!)
        printLine(text: "\n")
        printLine(text: "DIC: ")
        printLine(text: account.taxFormData.DIC!)
        printLine(text: "\n")
        printLine(text: "********************************")
        printLine(text: "\n")
        printLine(text: "Datum: ")
        printLine(text: day)
        printLine(text: "\n")
        printLine(text: "Cas: ")
        printLine(text: time)
        printLine(text: "\n")
        printLine(text: "Pokladna: ")
        printLine(text: self.account.eetData.cashRegisterID!)
        printLine(text: "\n")
        printLine(text: "Provozovna: ")
        printLine(text: self.account.eetData.premisesID!)
        printLine(text: "\n")
        printLine(text: "Cislo uctenky: ")
        printLine(text: self.cisloUctenky)
        printLine(text: "\n")
        sleep(1)
        printLine(text: "********************************")
        printLine(text: "\n")
        printHeader()
        printLine(text: "--------------------------------")
        printLine(text: "\n")
        printList(list: getProducts(list: getList()))
        printLine(text: "********************************")
        printLine(text: "\n")
        printLine(text: "Celkova cena: ")
        printLine(text: "\(price) Kc")
        printLine(text: "\n")
        printLine(text: "Cena bez DPH: ")
        printLine(text: "\(vat) Kc")
        printLine(text: "\n")
        printLine(text: "********************************")
        printLine(text: "\n")
        printLine(text: "              BKP")
        printLine(text: "\n")
        printLine(text: payload.bkp)
        sleep(1)
        printLine(text: "\n")
        printLine(text: "              FIK")
        printLine(text: "\n")
        printLine(text: payload.fik)
        printLine(text: "\n")
        printLine(text: "trzba evidovana v beznem rezimu")
        printLine(text: "\n")
        printLine(text: "\n")
        printLine(text: "\n")
        
    }
    
    func clearListData(){
        self.totalAmount = NSDecimalNumber.zero
        self.vat1Amount = NSDecimalNumber.zero
        self.vat2Amount = NSDecimalNumber.zero
        self.vat3Amount = NSDecimalNumber.zero
        self.vat4Amount = NSDecimalNumber.zero
        let products = getProducts(list: self.list)
        for product in products{
            product.quantity = 1
            product.removeFromList(self.list[0])
        }
    }
    
    func printList(list: [Product]){
        sleep(1)
        for product in list{
            printLine(text: "\(product.name!)")
            var space = product.name!.characters.count
            while space <= 18{
                printLine(text: " ")
                space = space + 1
            }
            printLine(text: "\(product.price!)")
            space = product.price!.characters.count
            while space <= 7{
                printLine(text: " ")
                space = space + 1
            }
            printLine(text: "\(product.quantity!)\n")
            sleep(1)
        }
    }
    
    func printHeader(){
        printLine(text: "zbozi              ")
        printLine(text: "cena    ")
        printLine(text: "ks")
        printLine(text: "\n")
    }
    
    func getList() -> [List] {
        return self.list
    }
    
    
    
    func getProducts(list: [List])->[Product]{
        let listProducts = list[0].product?.allObjects as! [Product]
        return listProducts
    }
    
    func getProductsPrice(products: [Product]){
        for product in products{
            let price = toDecimal(string: product.price!) * product.quantity!
            self.totalAmount = self.totalAmount + price
            if (product.vat == "21"){
                self.vat1Amount = self.vat1Amount + (price/1.21)
            }else if (product.vat == "15"){
                self.vat2Amount = self.vat2Amount + (price/1.15)
            }else if (product.vat == "10"){
                self.vat3Amount = self.vat3Amount + (price/1.10)
            }else if (product.vat == "0"){
                self.vat4Amount = self.vat4Amount + price
            }
        }
    }
    
    func toDecimal(string: String)->NSDecimalNumber{
        let formatter = NumberFormatter()
        formatter.generatesDecimalNumbers = true
        return formatter.number(from: string) as? NSDecimalNumber ?? 0
    }
    
    func printLine(text: String){
        
        let dataToSend = text.data(using: String.Encoding.utf8)
        
        if (self.mainPeripheral != nil) {
            self.mainPeripheral?.writeValue(dataToSend!, for: self.mainCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        } else {
            viewController?.getAlert(title: "Chyba", message: "Tiskárna není připojena")
            print("haven't discovered device yet")
        }
    }
    

    
    func checkData(account: DataModel) throws -> Bool{
        if account.eetData.cashRegisterID == "" {
            viewController?.getAlert(title: "", message: "Není nastavene cislo pokladny")
            return false
        }else if account.eetData.premisesID == ""{
            viewController?.getAlert(title: "", message: "Neni nastavene cislo provozovny")
            return false
        }else if account.taxFormData.pass == ""{
            viewController?.getAlert(title: "", message: "Neni nastavene heslo certifikatu")
            return false
        }else if account.taxFormData.DIC == ""{
            viewController?.getAlert(title: "", message: "Neni nastavene DIC")
            return false
        }else if account.taxFormData.ICO == ""{
            viewController?.getAlert(title: "", message: "Neni nastavene ICO")
            return false
        }else if self.mainPeripheral == nil{
            viewController?.getAlert(title: "", message: "Neni nastavena tiskarna")
            return false
        }else if self.rawData == nil{
            viewController?.getAlert(title: "", message: "Certifikat neni dostupny")
            return false
        }else{
            return true
        }
    }
    
    func addProduct(name: String, price: String, vat: String){
        let product: Product = NSEntityDescription.insertNewObject(forEntityName: "Product", into: DatabaseController.getContext()) as! Product
        product.name = name
        product.price = price
        product.vat = vat
        product.quantity = 1
        //parentView?.products.append(product)
        //parentView?.tableView.reloadData()
        DatabaseController.saveContext()
    }
    

    
}
