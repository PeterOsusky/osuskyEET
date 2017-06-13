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

private let _dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    return dateFormatter
}()


public final class ComunicationModel {
    
    /// Command for a payment.
    public struct PaymentCommand {
        
        /// Amount paid.
        public struct PaymentAmount {
            
            /// VAT payment. Contains VAT exclusive amount and VAT amount.
            public struct VATPayment {
                
                /// VAT Exclusive.
                public let vatExclusive: NSDecimalNumber
                
                /// VAT.
                public let vat: NSDecimalNumber
                
                public init(vatExclusive: NSDecimalNumber, vat: NSDecimalNumber) {
                    self.vatExclusive = vatExclusive
                    self.vat = vat
                }
                
            }
            
            /// VAT payment at base rate.
            public let baseRateVATPayment: VATPayment
            
            /// VAT payment at lowered rate.
            public let loweredRateVATPayment: VATPayment
            
            /// VAT payment at ultra lowered rate.
            public let ultraLoweredRateVATPayment: VATPayment
            
            /// Total amount.
            public let total: NSDecimalNumber
            
            public init(total: NSDecimalNumber,
                        baseRateVATPayment: VATPayment, loweredRateVATPayment: VATPayment, ultraLoweredVat: VATPayment) {
                self.baseRateVATPayment = baseRateVATPayment
                self.loweredRateVATPayment = loweredRateVATPayment
                self.ultraLoweredRateVATPayment = ultraLoweredVat
                self.total = total
            }
            
        }
        
        /// Command UUID.
        public let commandUUID: String = {
            return String.uuidString
        }()
        
        /// Number of the document. E.g. 000001
        public let documentNumber: String
        
        /// The amount paid.
        public let paymentAmount: PaymentAmount
        
        /// Date of the transaction.
        public let transactionDate: Date
        
        public init(documentNumber: String, paymentAmount: PaymentAmount, transactionDate: Date) {
            self.documentNumber = documentNumber
            self.paymentAmount = paymentAmount
            self.transactionDate = transactionDate
        }
        
    }
    
    /// A response from the EET server.
    public enum PaymentResponse {
        
        /// Payload in case of success.
        public struct Payload: CustomStringConvertible {
            
            /// BKP.
            public let bkp: String
            
            /// The date string.
            public let dateString: String
            
            /// FIK code.
            public let fik: String
            
            /// Message UUID.
            public let messageUUID: String
            
            /// Possible warnings.
            public let warnings: [String]
            
            
            public var description: String {
                var description = ""
                description += "BKP:\n\(self.bkp)\n\n"
                description += "Datum přijetí:\n\(self.dateString)\n\n"
                description = "FIK:\n\(self.fik)\n\n"
                description += "UUID zprávy:\n\(messageUUID)"
                
                if !self.warnings.isEmpty {
                    description += "\n\nVarování:\n"
                    description += self.warnings.flatMap({ "• " + $0 }).joined(separator: "\n")
                }
                
                return description
            }
            
        }
        
        public struct Error: CustomStringConvertible {
            
            /// Errors.
            public let errors: [String]
            
            /// Possible additional warnings.
            public let warnings: [String]
            
            public var description: String {
                var errorText = self.errors.flatMap({ "• " + $0 }).joined(separator: "\n")
                if !self.warnings.isEmpty {
                    errorText += "\n\nVarování:\n"
                    errorText += self.warnings.flatMap({ "• " + $0 }).joined(separator: "\n")
                }
                return errorText
            }
            
        }
        
        /// Success with the required data.
        case success(Payload)
        
        /// An error with multiple error strings.
        case error(Error)
    }
    
    public enum InitializationError: Error {
        
        /// Error with an error message.
        case errorString(String)
        
        /// Error represented by OSStatus. You should use
        /// SecCopyErrorMessageString(status, nil) to make this into a string.
        case errorCode(OSStatus)
    }
    
    public enum SendingError: Error {
        case cannotSerializeXML
        case coreFoundationError(CFError)
        case invalidResponse
        case localeSpecificDataMissing
        case localeSpecificDataIncomplete
        case networkError
        case unknownError
        
        public var localizedDescription: String {
            switch self {
            case .cannotSerializeXML:
                return "Chyba při vytváření XML dokumentu."
            case .coreFoundationError(let error):
                return error.localizedDescription
            case .invalidResponse:
                return "Špatná odpověď serveru."
            case .localeSpecificDataIncomplete:
                return "Převolby k EET nejsou vyplněny."
            case .localeSpecificDataMissing:
                return "Převolby k EET chybí."
            case .networkError:
                return "Chyba sítě - nelze načíst odpověď."
            case .unknownError:
                return "Nastala neznámá chyba."
            }
        }
    }
    
    /// EET certificate.
    public let certificate: DataModel.EET.Certificate
    
    /// Czech locale specific data.
    public let localeSpecificData: DataModel
    
    /// VAT registration ID - "DIČ".
    public let vatRegistrationID: String
    
    private func _createControlCodesElement(withCommand command: PaymentCommand) throws -> NSXMLElement {
        let element = NSXMLElement(name: "KontrolniKody")
        let children = try self._generatePKPandBKP(forCommand: command)
        children.forEach({ element.addChild($0) })
        return element
    }
    
    private func _createDataElement(withCommand command: PaymentCommand) throws -> NSXMLElement {
        guard let premisesID = self.localeSpecificData.eetData.premisesID else {
            throw SendingError.localeSpecificDataIncomplete
        }
        
        let element = NSXMLElement(name: "Data")
        element.addAttribute(withName: "dic_popl", stringValue: self.vatRegistrationID)
        element.addAttribute(withName: "id_provoz", stringValue: premisesID)
        element.addAttribute(withName: "id_pokl", stringValue: self.localeSpecificData.eetData.cashRegisterID!)
        element.addAttribute(withName: "porad_cis", stringValue: command.documentNumber)
        element.addAttribute(withName: "dat_trzby", stringValue: _dateFormatter.string(from: command.transactionDate))
        element.addAttribute(withName: "celk_trzba", stringValue: String(format: "%0.2f", command.paymentAmount.total.doubleValue))
        element.addAttribute(withName: "rezim", stringValue: "0")
        
        if !command.paymentAmount.baseRateVATPayment.vatExclusive.isZero {
            element.addAttribute(withName: "zakl_dan1", stringValue: String(format: "%0.2f", command.paymentAmount.baseRateVATPayment.vatExclusive.doubleValue))
            element.addAttribute(withName: "dan1", stringValue: String(format: "%0.2f", command.paymentAmount.baseRateVATPayment.vat.doubleValue))
        }
        
        if !command.paymentAmount.loweredRateVATPayment.vatExclusive.isZero {
            element.addAttribute(withName: "zakl_dan2", stringValue: String(format: "%0.2f", command.paymentAmount.loweredRateVATPayment.vatExclusive.doubleValue))
            element.addAttribute(withName: "dan2", stringValue: String(format: "%0.2f", command.paymentAmount.loweredRateVATPayment.vat.doubleValue))
        }
        
        if !command.paymentAmount.ultraLoweredRateVATPayment.vatExclusive.isZero {
            element.addAttribute(withName: "zakl_dan3", stringValue: String(format: "%0.2f", command.paymentAmount.ultraLoweredRateVATPayment.vatExclusive.doubleValue))
            element.addAttribute(withName: "dan3", stringValue: String(format: "%0.2f", command.paymentAmount.ultraLoweredRateVATPayment.vat.doubleValue))
        }
        
        return element
    }
    
    private func _createHeaderElement(withUUID uuid: String, validatingOnly: Bool) -> NSXMLElement {
        
        let date = Date()
        
        let element = NSXMLElement(name: "Hlavicka")
        element.addAttribute(withName: "uuid_zpravy", stringValue: uuid)
        element.addAttribute(withName: "dat_odesl", stringValue: _dateFormatter.string(from: date))
        element.addAttribute(withName: "prvni_zaslani", stringValue: "1")
        if validatingOnly {
            element.addAttribute(withName: "overeni", stringValue: "1")
        }
        
        return element
    }
    
    private func _createSignedInfoElement(withDigest digest: String, andBodyUUID bodyUUID: String) -> NSXMLElement {
        let signedInfoElement = NSXMLElement(name: "ds:SignedInfo")
        let canonicalizationMethodElement = NSXMLElement(name: "ds:CanonicalizationMethod")
        canonicalizationMethodElement.addAttribute(withName: "Algorithm", stringValue: "http://www.w3.org/2001/10/xml-exc-c14n#")
        
        
        let inclusive = NSXMLElement(name: "ec:InclusiveNamespaces")
        inclusive.addAttribute(withName: "xmlns:ec", stringValue: "http://www.w3.org/2001/10/xml-exc-c14n#")
        inclusive.addAttribute(withName: "PrefixList", stringValue: "soap")
        
        canonicalizationMethodElement.addChild(inclusive)
        
        signedInfoElement.addChild(canonicalizationMethodElement)
        
        
        let signMethod = NSXMLElement(name: "ds:SignatureMethod")
        signMethod.addAttribute(withName: "Algorithm", stringValue: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256")
        
        signedInfoElement.addChild(signMethod)
        
        let referenceElement = NSXMLElement(name: "ds:Reference")
        
        referenceElement.addAttribute(withName: "URI", stringValue: "#id-\(bodyUUID)")
        
        
        let transformsElement = NSXMLElement(name: "ds:Transforms")
        let transformElement = NSXMLElement(name: "ds:Transform")
        transformElement.addAttribute(withName: "Algorithm", stringValue: "http://www.w3.org/2001/10/xml-exc-c14n#")
        
        
        let inclusive2 = NSXMLElement(name: "ec:InclusiveNamespaces")
        inclusive2.addAttribute(withName: "xmlns:ec", stringValue: "http://www.w3.org/2001/10/xml-exc-c14n#")
        inclusive2.addAttribute(withName: "PrefixList", stringValue: "")
        
        transformElement.addChild(inclusive2)
        
        transformsElement.addChild(transformElement)
        referenceElement.addChild(transformsElement)
        
        
        let digestMeth = NSXMLElement(name: "ds:DigestMethod")
        digestMeth.addAttribute(withName: "Algorithm", stringValue: "http://www.w3.org/2001/04/xmlenc#sha256")
        referenceElement.addChild(digestMeth)
        
        referenceElement.addChild(NSXMLElement(name: "ds:DigestValue", stringValue: digest))
        
        signedInfoElement.addChild(referenceElement)
        return signedInfoElement
    }
    
    
    private func _generatePKPandBKP(forCommand command: PaymentCommand) throws -> [NSXMLElement] {
        let localeData = self.localeSpecificData
        
        let plaintext = [
            self.vatRegistrationID,
            localeData.eetData.premisesID!,
            localeData.eetData.cashRegisterID!,
            command.documentNumber,
            _dateFormatter.string(from: command.transactionDate),
            String(format: "%0.2f", command.paymentAmount.total.doubleValue)
            ].joined(separator: "|")
        
        let privateKey2 = try! PrivateKey(reference: self.certificate.privateKey)
        let clear = try ClearMessage(string: plaintext, using: .ascii)
        
        let signature = try clear.signed(with: privateKey2, digestType: .sha256)
        
        let data = signature.data
        let base64String = signature.base64String
        
        
        let pkpElement = NSXMLElement(name: "pkp", stringValue: base64String)
        pkpElement.addAttribute(withName: "digest", stringValue: "SHA256")
        pkpElement.addAttribute(withName: "cipher", stringValue: "RSA2048")
        pkpElement.addAttribute(withName: "encoding", stringValue: "base64")
        
        
        var bkpRaw = data.sha1Digest
        assert(bkpRaw.characters.count == 40)
        
        var bkpParts: [String] = []
        while !bkpRaw.isEmpty {
            let prefix = bkpRaw.prefix(ofLength: 8)
            bkpRaw = bkpRaw.deleting(prefix: prefix)
            bkpParts.append(prefix)
        }
        
        
        let bkpPartsWithSep = bkpParts.joined(separator: "-") as String
        let bkpElement = NSXMLElement(name: "bkp", stringValue: bkpPartsWithSep)
        bkpElement.addAttribute(withName: "digest", stringValue: "SHA1")
        bkpElement.addAttribute(withName: "encoding", stringValue: "base16")
        
        return [pkpElement, bkpElement]
    }
    
    private func _generateSOAPHeader(from soapBody: NSXMLElement, withBodyUUID bodyUUID: String) throws -> NSXMLElement {
        let headerElement = NSXMLElement(name: "SOAP-ENV:Header")
        
        headerElement.addAttribute(withName: "xmlns:SOAP-ENV", stringValue: "http://schemas.xmlsoap.org/soap/envelope/")
        
        let securityElement = NSXMLElement(name: "wsse:Security")
        
        securityElement.addAttribute(withName: "xmlns:wsse", stringValue: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd")
        securityElement.addAttribute(withName: "xmlns:wsu", stringValue: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd")
        securityElement.addAttribute(withName: "soap:mustUnderstand", stringValue: "1")
        
        
        let binarySecurityTokenUUID = String.uuidString
        let binarySecurityTokenElement = NSXMLElement(name: "wsse:BinarySecurityToken")
        binarySecurityTokenElement.addAttribute(withName: "EncodingType", stringValue: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary")
        binarySecurityTokenElement.addAttribute(withName: "ValueType", stringValue: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3")
        binarySecurityTokenElement.addAttribute(withName: "wsu:Id", stringValue: "X509-\(binarySecurityTokenUUID)")
        
        guard !self.certificate.certificateChain.isEmpty else {
            throw SendingError.localeSpecificDataIncomplete
        }
        
        let certificateData = SecCertificateCopyData(self.certificate.certificateChain[0]) as Data
        binarySecurityTokenElement.stringValue = certificateData.base64EncodedString()
        securityElement.addChild(binarySecurityTokenElement)
        
        let signatureElement = NSXMLElement(name: "ds:Signature")
        
        signatureElement.addAttribute(withName: "xmlns:ds", stringValue: "http://www.w3.org/2000/09/xmldsig#")
        signatureElement.addAttribute(withName: "Id", stringValue: "SIG-\(String.uuidString)")
        
        
        let bodyCopy = soapBody
        
        
        bodyCopy.addAttribute(withName: "xmlns:soap", stringValue: "http://schemas.xmlsoap.org/soap/envelope/")
        
        let canonicalXMLString = bodyCopy.canonicalXMLString
        
        
        guard let bodyData = canonicalXMLString.data(using: .utf8) else {
            throw SendingError.cannotSerializeXML
        }
        let signedInfoElement = self._createSignedInfoElement(withDigest: (bodyData as NSData).sha256Digest().base64EncodedString(), andBodyUUID: bodyUUID)
        signatureElement.addChild(signedInfoElement)
        
        
        let signedInfoCopy = signedInfoElement
        signedInfoCopy.addAttribute(withName: "xmlns:soap", stringValue: "http://schemas.xmlsoap.org/soap/envelope/")
        signedInfoCopy.addAttribute(withName: "xmlns:ds", stringValue: "http://www.w3.org/2000/09/xmldsig#")
        
        guard let signatureInfoData = signedInfoCopy.canonicalXMLString.data(using: .utf8) else {
            throw SendingError.cannotSerializeXML
        }
        
        let signatureValue = try self.certificate.signDataUsingRSASHA256(signatureInfoData)
        let signatureValueChild = NSXMLElement(name: "ds:SignatureValue", stringValue: signatureValue)
        signatureElement.addChild(signatureValueChild)
        
        
        
        let keyInfoElement = NSXMLElement(name: "ds:KeyInfo")
        keyInfoElement.addAttribute(withName: "Id", stringValue: "KI-\(String.uuidString)")
        
        let securityTokenReferenceElement = NSXMLElement(name: "wsse:SecurityTokenReference")
        securityTokenReferenceElement.addAttribute(withName: "xmlns:wsse", stringValue: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd")
        securityTokenReferenceElement.addAttribute(withName: "xmlns:wsu", stringValue: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd")
        securityTokenReferenceElement.addAttribute(withName: "wsu:Id", stringValue: "STR-\(String.uuidString)")
        
        
        let reference = NSXMLElement(name: "wsse:Reference")
        reference.addAttribute(withName: "URI", stringValue: "#X509-\(binarySecurityTokenUUID)")
        reference.addAttribute(withName: "ValueType", stringValue: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3")
        
        securityTokenReferenceElement.addChild(reference)
        keyInfoElement.addChild(securityTokenReferenceElement)
        signatureElement.addChild(keyInfoElement)
        securityElement.addChild(signatureElement)
        headerElement.addChild(securityElement)
        return headerElement
    }
    
    /// Initializes self with required information. Will throw if the certificate
    /// can't be found or if it cannot be validated (see validateCertificate()).
    /// Always throws InitializationError.
    public init(localeSpecificData: DataModel, vatRegistrationID: String) throws {
        self.localeSpecificData = localeSpecificData
        self.vatRegistrationID = vatRegistrationID
        
        guard let certificate = localeSpecificData.eetData.certificate else {
            throw InitializationError.errorString("Není nainstalovaný certifikát do tohoto účtu.")
        }
        
        self.certificate = certificate
        
        try self.validateCertificate()
    }
    
    
    
    /// Sends a payment command. If validatingOnly is set to true, the command
    /// will be executed with the testing flag.
    ///
    /// Throws a SendingError.
    public func sendPayment(_ payment: PaymentCommand, validatingOnly: Bool = false) throws -> PaymentResponse {
        let header = self._createHeaderElement(withUUID: payment.commandUUID, validatingOnly: validatingOnly)
        let data = try self._createDataElement(withCommand: payment)
        let controlCodes = try self._createControlCodesElement(withCommand: payment)
        let saleElement = NSXMLElement(name: "Trzba")
        saleElement.addAttribute(withName: "xmlns", stringValue: "http://fs.mfcr.cz/eet/schema/v3")
        
        saleElement.addChild(header)
        saleElement.addChild(data)
        saleElement.addChild(controlCodes)
        
        let soapEnvelope = NSXMLElement(name: "soap:Envelope")
        soapEnvelope.addAttribute(withName: "xmlns:soap", stringValue: "http://schemas.xmlsoap.org/soap/envelope/")
        
        let soapBodyUUID = String.uuidString
        let soapBody = NSXMLElement(name: "soap:Body")
        soapBody.addAttribute(withName: "xmlns:wsu", stringValue: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd")
        soapBody.addAttribute(withName: "wsu:Id", stringValue: "id-\(soapBodyUUID)")
        soapBody.addChild(saleElement)
        
        
        let soapHeader = try self._generateSOAPHeader(from: soapBody, withBodyUUID: soapBodyUUID)
        
        soapEnvelope.addChild(soapHeader)
        soapEnvelope.addChild(soapBody)
        
        let document = NSXMLDocument(rootElement: soapEnvelope)
        
        
        let downloadCenter = XUDownloadCenter (owner: self)
        let soapURLString: String
        if XUAppSetup.isRunningInDebugMode {
            soapURLString = "https://pg.eet.cz/eet/services/EETServiceSOAP/v3"
        } else {
            soapURLString = "https://pg.eet.cz/eet/services/EETServiceSOAP/v3" /// treba prepisat na prod.eet.cz:443
        }
        
        
        guard let responseXML = downloadCenter.downloadXMLDocument(at: URL(string: soapURLString), withRequestModifier: { (request: inout URLRequest) in
            request["SOAPAction"] = "http://fs.mfcr.cz/eet/OdeslaniTrzby"
            request.acceptType = "text/xml; charset=UTF-8"
            request.contentType = "text/xml; charset=UTF-8"
            request.httpMethod = "POST"
            
            let xmlString =  document.xmlString
            let xmlStringFixup = xmlString + "\n"
            let xmlData = xmlStringFixup.data(using: .utf8)!
            try? xmlData.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("message.xml"))
            
            print(xmlStringFixup)
            request.httpBody = xmlData
            request["Content-Length"] = "\(xmlData.count)"
        }) else {
            throw SendingError.networkError
        }
        
        guard let answerNode = responseXML.firstNode(onXPath: "soapenv:Envelope/soapenv:Body/eet:Odpoved") else {
            XULog("No soapenv:Body in \(responseXML)")
            throw SendingError.invalidResponse
        }
        let errorNodes = try answerNode.nodes(forXPath: "eet:Chyba")
        let warnings = try answerNode.nodes(forXPath: "eet:Varovani").flatMap({ $0.stringValue })
        
        
        
        if !errorNodes.isEmpty {
            XULog("Found errors in \(responseXML)")
            
            let errors = errorNodes.flatMap({ $0.stringValue })
            return PaymentResponse.error(ComunicationModel.PaymentResponse.Error(errors: errors, warnings: warnings))}
        
        guard
            let bkp = answerNode.stringValue(ofFirstNodeOnXPath: "eet:Hlavicka/@bkp"),
            let dateString = answerNode.stringValue(ofFirstNodeOnXPath: "eet:Hlavicka/@dat_prij"),
            let fik = answerNode.stringValue(ofFirstNodeOnXPath: "eet:Potvrzeni/@fik"),
            let messageUUID = answerNode.stringValue(ofFirstNodeOnXPath: "eet:Hlavicka/@uuid_zpravy")
            else {
                XULog("Did not find one of the required values in \(responseXML)")
                throw SendingError.invalidResponse
        }
        let payload = PaymentResponse.Payload(bkp: bkp, dateString: dateString, fik: fik, messageUUID: messageUUID, warnings: warnings)
        return PaymentResponse.success(payload)
    }
    
    
    
    
    //validatind users certificate
    public func validateCertificate() throws {
        for certificate in self.certificate.certificateChain {
            let policy = SecPolicyCreateBasicX509()
            var trust: SecTrust?
            let trustStatus = SecTrustCreateWithCertificates(certificate, policy, &trust)
            guard trust != nil else {
                throw InitializationError.errorCode(trustStatus)
            }
            
            var evaluationResult: SecTrustResultType = SecTrustResultType.fatalTrustFailure
            SecTrustEvaluate(trust!, &evaluationResult)
            
            guard evaluationResult == .unspecified || evaluationResult == .proceed else {
                throw InitializationError.errorString("Certifikát není validní. Zkontrolujte, zda nevypršel a zda máte nainstalovaný i kořenový certifikát.")
            }
        }
    }
}

    extension ComunicationModel: XUDownloadCenterOwner {
        
        public func downloadCenter(_ downloadCenter: XUDownloadCenter, didEncounterError error: XUDownloadCenterError) {
        }
        
        public var name: String {
            return "EET"
        }
}

