//
//  Upload.swift
//  YSoft SafeQ Mobile Print SDK - sample app
//
//  Created by Miriam Cabadajová on 15/04/2020.
//  Copyright © 2020 Y Soft Corporation, a.s. All rights reserved.
//

import UIKit
import WebKit

protocol UploadDelegate {
    func notifyUser(title: String, message: String)
    func isUploadBeingProcessed(flag: Bool)
    func selectBtnIsVisible(flag: Bool)
    func reloadTableview(printJobs: Array<PrintJob>)
}

class Upload: NSObject, URLSessionDelegate, WKNavigationDelegate {
    private var serverURI: String
    private var printJobs: Array<PrintJob> = Array()
    private var token: String
    private var deliveryEndpoint: DeliveryEndpoint
    
    private var uploadDelegate: UploadDelegate
    private var numberOfUploadedFiles = 0
    
    
    init(myServerURI: String, myPrintJobs: Array<PrintJob>, myDeliveryEndpoint: DeliveryEndpoint, myToken: String, myUploadDelegate: UploadDelegate) {
        serverURI = myServerURI
        printJobs = myPrintJobs
        deliveryEndpoint = myDeliveryEndpoint
        token = myToken
        uploadDelegate = myUploadDelegate
    }
    
    private func getURL(suffix: String) -> URL {
        return URL(string: self.serverURI + suffix)!
    }
    
    func handleUpload() {
        uploadDelegate.isUploadBeingProcessed(flag: true)
        uploadDelegate.selectBtnIsVisible(flag: false)
        
        if (deliveryEndpoint == .mig) {
            handleMigUpload()
            return
        }

        handleEuiUpload()
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!) )
    }
    
    private func uploadCompletionHandler(responseData: Data?, response: URLResponse?, error: Error?) {
        if(error != nil){
            uploadDelegate.notifyUser(title: "Upload failed", message: error!.localizedDescription)
            uploadDelegate.isUploadBeingProcessed(flag: false)
            uploadDelegate.selectBtnIsVisible(flag: true)
            return
        }
        
        guard let responseData = responseData else {
            uploadDelegate.isUploadBeingProcessed(flag: false)
            uploadDelegate.selectBtnIsVisible(flag: true)
            return
        }
        
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("uploaded to: \(responseString)")
        }
        
        if numberOfUploadedFiles > 1 {
            uploadDelegate.notifyUser(title: "Upload completed", message: "Uploaded " + String(numberOfUploadedFiles) + " files")
        } else {
            uploadDelegate.notifyUser(title: "Upload completed", message: "Uploaded 1 file")
        }
        
        uploadDelegate.isUploadBeingProcessed(flag: false)
        uploadDelegate.selectBtnIsVisible(flag: true)
        
        
    }
}

// MARK: EUI upload
extension Upload {
    
    func handleEuiUpload() {
        getTokenForUpload()
    }
    
    private func getTokenForUpload() {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue:OperationQueue.main)
        let url = self.getURL(suffix: "upload-job")
        
        var pageRequest = URLRequest(url: url)
        pageRequest.httpShouldHandleCookies = true
        pageRequest.timeoutInterval = 5
        let task = session.dataTask(with: pageRequest, completionHandler:  self.getTokenForUploadCompletionHandler)
        task.resume()
    }
    
    
    private func getTokenForUploadCompletionHandler(responseData: Data?, response: URLResponse?, error: Error?) {
        if (response == nil || responseData == nil) {
            uploadDelegate.notifyUser(title: "Upload failed", message: "Check your internet connection")
            return
        }
        
        let contents = String(data: responseData!, encoding: .ascii)
        guard let content = contents else { return  }
        let matched = self.matches(for: "_csrf\".*", in: content)
        let first = matched[0]
        let token = first.split(separator: "\"")[2]
        
        var unsuccessfulUpload = false
        numberOfUploadedFiles = 0
        
        var i = 0
        while i < printJobs.count {
            if self.uploadFileEui(token: "" + token, fileUrl: printJobs[i].url, index: i){
                //if the upload succeeded, remove file from the printJobs array
                printJobs.remove(at: i)
                uploadDelegate.reloadTableview(printJobs: printJobs)
            } else {
                //if upload fails, keep file in the array and increase index to enable upload of next file
                unsuccessfulUpload = true
                i += 1
            }
        }
        
        if unsuccessfulUpload {
            var errorString = ""
            for file in printJobs {
                errorString += file.url.lastPathComponent + "\n"
            }
        }
    }
    
    private func matches(for regex: String, in text: String) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            return results.map { nsString.substring(with: $0.range)}
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    private func uploadFileEui(token: String, fileUrl: URL, index: Int) -> Bool {
        let uploadURL =  self.getURL(suffix: "upload-job")

        let filename = fileUrl.lastPathComponent
        // generate boundary string using a unique per-app string
        let boundary = UUID().uuidString
        
        let fieldName = "bw"
        var fieldValue = "false"
        
        if printJobs[index].isBwSelected {
            fieldValue = "true"
        }
        
        let fieldName2 = "duplex"
        var fieldValue2 = "false"
        
        if printJobs[index].isDuplexSelected {
            fieldValue2 = "true"
        }
       
        // Set the URLRequest to POST and to the specified URL
        var urlRequest = URLRequest(url: uploadURL)
        urlRequest.httpMethod = "POST"
        urlRequest.httpShouldHandleCookies = true
        urlRequest.setValue(token, forHTTPHeaderField: "X-CSRF-TOKEN")

        // Set Content-Type Header to multipart/form-data, this is equivalent to submitting form data with file upload in a web browser
        // And the boundary is also set here
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // Add the reqtype field and its value to the raw http request data
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(fieldName)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(fieldValue)".data(using: .utf8)!)
        
        // Add the userhash field and its value to the raw http request data
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(fieldName2)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(fieldValue2)".data(using: .utf8)!)
        
        // Add the image data to the raw http request data
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"importFile\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        
        // TODO: Upload correct conntent type. Current EUI seems that it does not care
        data.append("Content-Type: image/\(fileUrl.pathExtension)\r\n\r\n".data(using: .utf8)!)
        
        do {
            
            _ = fileUrl.startAccessingSecurityScopedResource()
            data.append(try Data(contentsOf: fileUrl))
            fileUrl.stopAccessingSecurityScopedResource()
            
            // End the raw http request data, note that there is 2 extra dash ("-") at the end, this is to indicate the end of the data
            // According to the HTTP 1.1 specification https://tools.ietf.org/html/rfc7230
            data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            // Send a POST request to the URL, with the data we created earlier
            //let session = URLSession.shared
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue:OperationQueue.main)
            
            session.uploadTask(with: urlRequest, from: data, completionHandler: self.uploadCompletionHandler).resume()
            
        } catch {
            print(error)
            return false
        }
        numberOfUploadedFiles += 1
        return true
    }
}

// MARK: MIG upload
extension Upload {
    func handleMigUpload() {
        var unsuccessfulUpload = false
        numberOfUploadedFiles = 0
        
        var i = 0
        while i < printJobs.count {
            if self.uploadFileMig(fileUrl: printJobs[i].url){
                //if the upload succeeded, remove file from the myFiles array
                printJobs.remove(at: i)
                uploadDelegate.reloadTableview(printJobs: printJobs)
            } else {
                //if upload fails, keep file in the array and increase index to enable upload of next file
                unsuccessfulUpload = true
                i += 1
            }
        }
        
        if unsuccessfulUpload {
            var errorString = ""
            for file in printJobs {
                errorString += file.url.lastPathComponent + "\n"
            }
        }
    }
    
    private func uploadFileMig(fileUrl: URL) -> Bool {

        let filename = fileUrl.lastPathComponent
        let uploadURL =  self.getURL(suffix: "ipp/print")
        
        // Set the URLRequest to POST and to the specified URL
        var urlRequest = URLRequest(url: uploadURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/ipp", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/html, image/gif, image/jpeg, *; q=.2, */*; q=.2", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Basic \(self.token)", forHTTPHeaderField: "Authorization")
        
        
        var data = Data()
        
        // IPP Version
        data.append(contentsOf: [0x01, 0x01])
        
        // Operation ID
        data.append(contentsOf: [0x00, 0x02])
        
        // Request ID
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        
        // Operational attributes - signature
        data.append(0x01)
        
        // Operational attributes
        // Charset tag
        data.append(contentsOf: [0x47, 0x00, UInt8("attributes-charset".count)])
        data.append("attributes-charset".data(using: .utf8)!)
        data.append(contentsOf: [0x00, UInt8("us-ascii".count)])
        data.append("us-ascii".data(using: .utf8)!)

        // Natural language tag
        data.append(contentsOf: [0x48, 0x00, UInt8("attributes-natural-language".count)])
        data.append("attributes-natural-language".data(using: .utf8)!)
        data.append(contentsOf: [0x00, UInt8("en-us".count)])
        data.append("en-us".data(using: .utf8)!)

        // Name without language tag
        data.append(contentsOf: [0x42, 0x00, UInt8("job-name".count)])
        data.append("job-name".data(using: .utf8)!)
        data.append(contentsOf: [0x00, UInt8(filename.count)])
        data.append(filename.data(using: .utf8)!)

        // Boolean tag
        data.append(contentsOf: [0x22, 0x00, UInt8("ipp-attribute-fidelity".count)])
        data.append("ipp-attribute-fidelity".data(using: .utf8)!)
        data.append(contentsOf: [0x00, 0x01, 0x01])

        // Job attributes - signature
        data.append(0x02)
        
        // Job attributes
        // Integer tag
        data.append(contentsOf: [0x21, 0x00, UInt8("copies".count)])
        data.append("copies".data(using: .utf8)!)
        data.append(contentsOf: [0x00, 0x04, 0x00, 0x00, 0x00, 0x01])

        // Keyword tag
        data.append(contentsOf: [0x44, 0x00, UInt8("sides".count)])
        data.append("sides".data(using: .utf8)!)
        data.append(contentsOf: [0x00, UInt8("one-sided".count)])
        data.append("one-sided".data(using: .utf8)!)

        // End attributes - signature
        data.append(0x03)
        
        do {
            _ = fileUrl.startAccessingSecurityScopedResource()
            data.append(try Data(contentsOf: fileUrl))
            fileUrl.stopAccessingSecurityScopedResource()
            
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue:OperationQueue.main)
            
            session.uploadTask(with: urlRequest, from: data, completionHandler: self.uploadCompletionHandler).resume()

        } catch {
              print(error)
              return false
        }
        
        numberOfUploadedFiles += 1
        return true
    }
}
