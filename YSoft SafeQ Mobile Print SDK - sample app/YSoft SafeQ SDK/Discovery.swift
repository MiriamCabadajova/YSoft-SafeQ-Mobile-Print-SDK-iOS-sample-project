//
//  Discovery.swift
//  YSoft SafeQ Mobile Print SDK - sample app
//
//  Created by Miriam Cabadajova on 24/04/2020.
//  Copyright © 2020 Y Soft Corporation, a.s. All rights reserved.
//

import UIKit
import WebKit

//Service discovery based on https://github.com/shsteven/Swift-Sample-Code/blob/master/Bonjour/Bonjour/BonjourDiscovery.swift
extension NetService {
    //get the printer URL
     func textRecordField(field: String) -> String?
     {
         guard
             let data = self.txtRecordData(),
             let field = NetService.dictionary(fromTXTRecord: data)[field]
             else { return nil }

         return String(data: field, encoding: String.Encoding.utf8)
     }
}

protocol DiscoveryDelegate {
    func notifyUser(title: String, message: String)
    func setAllButtons(flag: Bool)
    func promptUserForURLConfirmation(url: String)
}
class Discovery: NSObject, URLSessionDelegate, NetServiceBrowserDelegate, NetServiceDelegate  {

    private var domainsForVerification:[String] = []
    private var currentUrl = ""
    private var discoveryDelegate: DiscoveryDelegate
    var serverName: String
    var services = [NetService] ()
    
    init(myServername: String, myDiscoveryDelegate: DiscoveryDelegate) {
        serverName = myServername
        discoveryDelegate = myDiscoveryDelegate
    }
    
    func netServiceDidResolveAddress (_ sender: NetService) {
            
        var hostname = [CChar] (repeating: 0, count: Int (NI_MAXHOST))
        guard let data = sender.addresses? .first else {return}
        do {
            try data.withUnsafeBytes {(pointer: UnsafePointer<sockaddr>) in
                guard getnameinfo (pointer, socklen_t (data.count),&hostname, socklen_t (hostname.count), nil, 0, NI_NUMERICHOST) == 0
                    else {throw NSError (domain: "error_domain", code: 0, userInfo: .none)}
                let address = String (cString: hostname)
                
                let printerPath = "http://\(address):631/" + (sender.textRecordField(field: "rp") ?? "")
                guard let printerUrl = URL(string: printerPath)
                    else {  return }
                print(printerUrl)
                _ = UIPrinter(url: printerUrl)
                self.domainsForVerification.append(printerPath)

            }
        } catch {
            print (error)
        }
        
    }
    
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print(service)
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    let serviceBrowser = NetServiceBrowser()
    
    func startDiscovery() {
        services.removeAll()
        serviceBrowser.delegate = self
        serviceBrowser.schedule(in: .current, forMode: .default)
        serviceBrowser.searchForServices(ofType: "_ipp._tcp.", inDomain:"local.")
    }
    
    func netServiceDidStop(_ sender: NetService) {
        print("search was stopped")
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!) )
    }
    
    func discover () {
        discoveryDelegate.setAllButtons(flag: false)
        domainsForVerification.removeAll()
        
        startDiscovery()
        //delay because of service discovery
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if (self.serverName != "") {
                
                guard let returnUrl = URL(string: self.serverName) else {
                    self.discoveryDelegate.notifyUser(title: "Discovery failed", message: "Empty input string detected")
                    self.discoveryDelegate.setAllButtons(flag: true)
                    return
                }
                
                var currentDomain = returnUrl.host
                // Text in the textfield is not valid, let's assume that it's a domain
                if (currentDomain == nil) {
                    // When user just enters random domain (not valid URL), try safeq6 subdomain first to speed up search
                    currentDomain = self.serverName
                    if ( (currentDomain?.contains("safeq6")) == false) {
                        self.addDomainsForVerification(prefix: "safeq6", enteredUrl: currentDomain ?? "")
                    }
                    self.addDomainsForVerification(prefix: "", enteredUrl: currentDomain ?? "")
                    
                } else {
                    // When user enters valid URL, try the domain first then try safeq6 subdomain
                    self.addDomainsForVerification(prefix: "", enteredUrl: currentDomain ?? "")

                    if ( (currentDomain?.contains("safeq6")) == false) {
                        self.addDomainsForVerification(prefix: "safeq6", enteredUrl: currentDomain ?? "")
                    }
                }
            }
        
        
            if (self.domainsForVerification.count == 0) {
                self.discoveryDelegate.notifyUser(title: "Discovery", message: "No Print Server found")
                self.discoveryDelegate.setAllButtons(flag: true)
                return
            }
                
            self.verifyDomain()
        }
    }
    
    private func addDomainsForVerification(prefix: String, enteredUrl: String) {
        var newPrefix = ""
        if (prefix != "") {
            newPrefix = "\(prefix)."
        }
        
        domainsForVerification.append("https://\(newPrefix)\(enteredUrl):8050")
        domainsForVerification.append("https://\(newPrefix)\(enteredUrl)")
        domainsForVerification.append("https://\(newPrefix)\(enteredUrl)/end-user/ui/")
        domainsForVerification.append("https://\(newPrefix)\(enteredUrl):9443/end-user/ui/")

    }
    
    func verifyDomain() {
        if (self.domainsForVerification.count == 0) {
            discoveryDelegate.notifyUser(title: "Discovery", message: "No Print Server found")
            discoveryDelegate.setAllButtons(flag: true)
            return
        }
        
        let domain = self.domainsForVerification[0]
        self.domainsForVerification.removeFirst()
        self.findServerInDomain(urlString: domain)
    }
    
    private func findServerInDomain(urlString: String) {
        let url = URL(string: urlString)
        var pageRequest = URLRequest(url: url!)
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue:OperationQueue.main)
        
        // If server is using just DROP then response will never come (e.g. https://ysoft.local)
        // Set interval to 2 to speed up search
        pageRequest.timeoutInterval = 2
        let task = session.dataTask(with: pageRequest, completionHandler:  self.serverDiscoveryCompletionHandler)
        
        task.resume()
    }
    
    private func serverDiscoveryFailed() {
        // URL is not valid, try another one
        self.verifyDomain()
    }
    
    func matches(for regex: String, in text: String) -> [String] {
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
    
    private func serverDiscoveryCompletionHandler(data: Data?, response: URLResponse?, error: Error?) {
        if (response == nil) {
            // Server not reachable
            self.serverDiscoveryFailed()
            return
        }
        
        let httpResponse = response as! HTTPURLResponse
        if (data == nil) {
            // No response from server
            self.serverDiscoveryFailed()
            return
        }
        
        if (httpResponse.statusCode == 404) {
            // No interface for upload on the server - page not found 404
            self.serverDiscoveryFailed()
            return
        }
        
        var url = httpResponse.url!.absoluteString
        let contents = String(data: data!, encoding: .ascii)
        guard let content = contents else { return  }
        
        if (url.contains("631")) {
            discoveryDelegate.promptUserForURLConfirmation(url: url)
            return
        }
        
        if ((content.starts(with: "MIG")) || (content.starts(with: "AP hello"))) {
            discoveryDelegate.promptUserForURLConfirmation(url: url)
            return
        }
        
        let matched = self.matches(for: "_csrf\".*", in: content)
        if (matched.count == 0) {
            // Incompatible server interface, no token found - it's not a EUI
            self.serverDiscoveryFailed()
            return
        }
        
        if (url.contains("/login")) {
            url.removeLast(5)
        }
        
        discoveryDelegate.promptUserForURLConfirmation(url: url)
    }

}
