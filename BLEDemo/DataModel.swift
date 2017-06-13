//
//  MainModel.swift
//  BLEDemo
//
//  Created by Peter on 08/05/2017.
//  Copyright © 2017 Peter Osusky. All rights reserved.
//

import Foundation
import Security
import SwiftyRSA


private func _loadCertificateChainAndPrivateKey(from rawData: Data, andPassword password: String) throws -> ([SecCertificate], SecKey) {
    let options: NSDictionary = [kSecImportExportPassphrase: password ]
    var itemsOptional: CFArray?
    
    let status = SecPKCS12Import(rawData as CFData, options as CFDictionary, &itemsOptional)
    
    guard let cfItems = itemsOptional, status == noErr else {
        throw DataModel.EET.Certificate.Error.errorCode(status)
    }
    
    let items = (cfItems as NSArray) as [AnyObject]
    guard
        let itemDictionary = items.first as? [String : Any],
        let identityOpt = itemDictionary[kSecImportItemIdentity as String],
        let certificateOpt = itemDictionary[kSecImportItemCertChain as String]
        else {
            throw DataModel.EET.Certificate.Error.errorString("Soubor .p12 neobsahuje privátní klíč.")
    }
    
    var privateKeyOptional: SecKey?
    let identity = identityOpt as! SecIdentity
    let privateKeyStatus = SecIdentityCopyPrivateKey(identity, &privateKeyOptional)
    guard let privateKey = privateKeyOptional, privateKeyStatus == noErr else {
        throw DataModel.EET.Certificate.Error.errorCode(privateKeyStatus)
    }
    
    return ((certificateOpt as! CFArray) as! [SecCertificate], privateKey)
}

public final class DataModel: NSObject, NSCoding {
    
    public final class TaxForm: NSObject, NSCoding {
        
        /// city
        public var city: String? = ""
        
        /// password to certificate
        public var pass: String? = ""
        
        /// name of the shop
        public var name: String? = ""
        
        /// ICO number
        public var ICO: String? = ""
        
        /// DIC number
        public var DIC: String? = ""
        
        /// name of certificate in device.
        public var certificateName: String? = ""
        
        
        public func encode(with coder: NSCoder) {
        }
        
        public override  init() {
            super.init()
        }
        
        public init?(coder decoder: NSCoder) {
        }
        
    }
    
    public final class EET: NSObject, NSCoding{
        
        // certificate class, contains all data about it
        public final class Certificate: NSObject, NSCoding {
            
            public enum Error: Swift.Error {
                case errorString(String)
                case errorCode(OSStatus)
            }
            
            //Certificate
            @nonobjc
            public let certificateChain: [SecCertificate]
            
            // Password for the rawData
            public let password: String
            
            // Private key
            public let privateKey: SecKey
            
            // Raw data of the PKCS12 file
            public let rawData: Data
            
            
            
            public func encode(with coder: NSCoder) {
                coder.encode(self.rawData, forKey: "certificateData")
                coder.encode(self.password, forKey: "password")
            }
            
            /// Inits with data and password. Always throws Certificate.Error.
            public init(rawData: Data, password: String) throws {
                self.rawData = rawData
                self.password = password
                
                let privates = try _loadCertificateChainAndPrivateKey(from: rawData, andPassword: password)
                self.certificateChain = privates.0
                self.privateKey = privates.1
                super.init()
            }
            
            public init?(coder decoder: NSCoder) {
                guard
                    let data = decoder.decodeObject(forKey: "certificateData") as? Data,
                    let password = decoder.decodeObject(forKey: "password") as? String
                    else {
                        return nil
                }
                
                guard let privates = try? _loadCertificateChainAndPrivateKey(from: data, andPassword: password) else {
                    return nil
                }
                
                self.rawData = data
                self.password = password
                self.certificateChain = privates.0
                self.privateKey = privates.1
            }
            
            /// Signes data by hashing it using SHA256 and then encrypting result
            /// with RSA. Throws XUEETCommunicator.SendingError
            public func signDataUsingRSASHA256(_ datas: Data) throws -> String {
                
                let privateKey2 = try! PrivateKey(reference: privateKey)
                let clear = try ClearMessage(data: datas)
                let signature = try clear.signed(with: privateKey2, digestType: .sha256)
                
                let data = signature.data
                let base64String = signature.base64String
                
                return base64String
            }
            
        }
        
        /// ID of cash register used for eet
        public var cashRegisterID: String? = ""
        
        // Certificate data
        public var certificate: Certificate?
        
        // ID of premises used for eet
        public var premisesID: String? = ""
        
        
        public func encode(with coder: NSCoder) {
            coder.encode(self.certificate, forKey: "certificate")
            coder.encode(self.premisesID, forKey: "premisesID")
        }
        
        public override init() {
            super.init()
        }
        
        public init?(coder decoder: NSCoder) {
            self.certificate = decoder.decodeObject(forKey: "certificate") as? Certificate
            self.premisesID = decoder.decodeObject(forKey: "premisesID") as? String
            
            super.init()
        }
        
    }
    
    /// Data in regards to EET.
    public var eetData: EET
    
    /// Variables used on various tax forms.
    public var taxFormData: TaxForm
    
    public func encode(with coder: NSCoder) {
        coder.encode(self.eetData, forKey: "eetData")
        coder.encode(self.taxFormData, forKey: "taxData")
    }
    
    public init(taxFormVariables: TaxForm = TaxForm(), eetData: EET = EET()) {
        self.taxFormData = taxFormVariables
        self.eetData = eetData
        
        super.init()
    }
    
    public init?(coder decoder: NSCoder) {
        TaxForm.initialize()
        EET.initialize()
        EET.Certificate.initialize()
        
        self.eetData = (decoder.decodeObject(forKey: "eetData") as? EET)!
        self.taxFormData = (decoder.decodeObject(forKey: "taxData") as? TaxForm)!
        
        super.init()
    }
    
}



