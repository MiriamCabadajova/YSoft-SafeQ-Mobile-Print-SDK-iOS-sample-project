//
//  Login.swift
//  YSoft SafeQ Mobile Print SDK - sample app
//
//  Created by Miriam Cabadajová on 15/04/2020.
//  Copyright © 2020 Y Soft Corporation, a.s. All rights reserved.
//

import UIKit

protocol LoginDelegate {
    func notifyUser(title: String, message: String)
    func showLoginProgressBar(flag: Bool)
    func presentUploadStoryboard(deliveryEndpoint: DeliveryEndpoint)
    func savePreferences()
    func clearPreferences()
}

class Login: NSObject, URLSessionDelegate {
    private var serverURI: String
    private var login: String
    private var password: String
    private var saveCredentials: Bool
    private var loginDelegate: LoginDelegate
    private var deliveryEndpoint: DeliveryEndpoint = .mig
    
    init(myServerURI: String, myLogin: String, myPassword: String, saveCredentialsChecked: Bool, myLoginDelegate: LoginDelegate) {
        serverURI = myServerURI
        login = myLogin
        password = myPassword
        saveCredentials = saveCredentialsChecked
        loginDelegate = myLoginDelegate
    }
    
    public func handleLogin() {
        loginDelegate.showLoginProgressBar(flag: true)
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue:OperationQueue.main)
        
        let baseUrl = serverURI
        if baseUrl.contains("end-user") {
            deliveryEndpoint = .eui
        } else {
            deliveryEndpoint = .mig
        }
        
        if (deliveryEndpoint == .mig) {
            loginMig()
            return
        }
        
        let url = URL(string: serverURI + "login")!
        //let url = URL(string: "https://demo6.ysoft.com:9443/end-user/ui/login")!
        var pageRequest = URLRequest(url: url)
        pageRequest.httpShouldHandleCookies = true
        pageRequest.timeoutInterval = 5
        let task = session.dataTask(with: pageRequest, completionHandler:  self.loginGetCompletionHandler)
        task.resume()
    }
    
    func loginGetCompletionHandler(data: Data?, response: URLResponse?, error: Error?) {
        let cookies:[HTTPCookie] = HTTPCookieStorage.shared.cookies! as [HTTPCookie]
        for cookie:HTTPCookie in cookies as [HTTPCookie] {
            //var cookieValue : String = "CookieName=" + cookie.value as String
            print(cookie.name as String)
            print(cookie.value as String)
        } // end: for
        
        if (data == nil) {
            handleUnsuccessfulLogin(notificationMessage: "Unable to connect to server for login")
            return
        }
        let contents = String(data: data!, encoding: .ascii)

        
        guard let content = contents else { return  }
        let matched = self.matches(for: "_csrf\".*", in: content)
        if (matched.count == 0) {
            handleUnsuccessfulLogin(notificationMessage: "Server does not provide EU/MPS interface.")
            return
        }
        
        let first = matched[0]
        let token = first.split(separator: "\"")[2]
        print(token)
        
        let loginUrl = URL(string: serverURI + "j_spring_security_check")!
        //let loginUrl = URL(string: "https://demo6.ysoft.com:9443/end-user/ui/j_spring_security_check")!
        
        var request = URLRequest(url: loginUrl)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = true
        
        let loginString = login
        let passwordString = password
        
        var requestBodyString = "username="
        requestBodyString += loginString
        requestBodyString += "&password="
        requestBodyString += passwordString
        requestBodyString += "&_csrf="
        requestBodyString += token
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBodyString.data(using:String.Encoding.ascii, allowLossyConversion: false)
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue:OperationQueue.main)

        let loginTask = session.dataTask(with: request, completionHandler: self.loginCompletionHandler)
        loginTask.resume()
        
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
    
    func loginMig() {

        let loginUrl =  URL(string: serverURI + "ipp/print")!
        //let loginUrl = URL(string: "https://demo6.ysoft.com:9443/end-user/ui/j_spring_security_check")!
        

        var urlRequest = URLRequest(url: loginUrl)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/ipp", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/html, image/gif, image/jpeg, *; q=.2, */*; q=.2", forHTTPHeaderField: "Accept")
        let plainAuth = (self.login + ":" + self.password).data(using: String.Encoding.utf8)
        if let base64 = plainAuth?.base64EncodedString(options: []) {
            urlRequest.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
       }
        
        var data = Data()
        
        // IPP Version
        data.append(contentsOf: [0x01, 0x01])
        
        // Operation ID
        data.append(contentsOf: [0x00, 0x01])
        
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
        data.append(contentsOf: [0x00, UInt8("ipp-print.jpg".count)])
        data.append("ipp print.jpg".data(using: .utf8)!)

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

        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue:OperationQueue.main)

        let loginTask = session.uploadTask(with: urlRequest, from: data, completionHandler: self.loginCompletionHandlerMig)
        loginTask.resume()
        
        if (saveCredentials) {
            loginDelegate.savePreferences()
        } else {
        }
    }

    
    func loginCompletionHandlerMig(data: Data?, response: URLResponse?, error: Error?) {
        if error != nil {
            loginDelegate.notifyUser(title: "Login unsuccessful", message: "Unsupported URL")
            loginDelegate.showLoginProgressBar(flag: false)
            return
        }

        if let httpResponse = response as? HTTPURLResponse {
            if (httpResponse.statusCode == 401) {
                loginDelegate.notifyUser(title: "Login unsuccessful", message: "Invalid credentials")
                loginDelegate.showLoginProgressBar(flag: false)
                return
            }
        }


        loginDelegate.presentUploadStoryboard(deliveryEndpoint: deliveryEndpoint)
        loginDelegate.showLoginProgressBar(flag: false)
    }


    
    func loginCompletionHandler(data: Data?, response: URLResponse?, error: Error?) {
        if (data == nil) {
            handleUnsuccessfulLogin(notificationMessage: "AuthenticationFailed")
            return
        }
        let contentsLogin = String(data: data!, encoding: .ascii)
        let matched = self.matches(for: "Login to YSoft SafeQ", in: contentsLogin!)
        if (matched.count > 0) {
            handleUnsuccessfulLogin(notificationMessage: "Invalid Credentials")
            return
        }
        //if login succeeds and save credentials checkbox is checked, save preferences
        if saveCredentials {
            loginDelegate.savePreferences()
        }
        
        //skip login ViewController
        loginDelegate.presentUploadStoryboard(deliveryEndpoint: deliveryEndpoint)
        
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        
        switch authenticationMethod {
        case NSURLAuthenticationMethodClientCertificate:
            print("handle client certificates")
        case NSURLAuthenticationMethodServerTrust:
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!) )
        default:
            print(authenticationMethod)
            //NSURLAuthenticationMethodServerTrust
            completionHandler(.performDefaultHandling, nil)
        }
        
    }

    
    func handleUnsuccessfulLogin(notificationMessage: String) {
        //if login fails and hide login screen toggle is enabled (saved credentials are not empty) -> replace "splash screen" with login ViewController
        loginDelegate.notifyUser(title: "Login unsuccessful", message: notificationMessage)
        loginDelegate.showLoginProgressBar(flag: false)
    }
}


