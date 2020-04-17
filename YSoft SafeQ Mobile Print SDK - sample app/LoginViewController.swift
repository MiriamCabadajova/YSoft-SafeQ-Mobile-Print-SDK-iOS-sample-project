//
//  LoginViewController.swift
//  YSoft SafeQ Mobile Print SDK - sample app
//
//  Created by Miriam Cabadajová on 15/04/2020.
//  Copyright © 2020 Y Soft Corporation, a.s. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController, LoginDelegate {
    
    @IBOutlet weak var serverURITextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func showLoginProgressBar(flag: Bool) {
        setAllButtons(flag: !flag)
        
        if flag {
            loginButton.setTitle("Logging in ... ", for: .normal)
        } else {
            loginButton.setTitle("Login", for: .normal)
        }
    }
    
    func notifyUser(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func presentUploadStoryboard(deliveryEndpoint: DeliveryEndpoint) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "UploadScreen") as? UploadViewController
        
        let plainAuth = (usernameTextField.text! + ":" + self.passwordTextField.text!).data(using: String.Encoding.utf8)
        if let base64 = plainAuth?.base64EncodedString(options: []) {
            vc?.token = base64
        }
        
        vc?.serverURI = self.serverURITextField.text!
        vc?.deliveryEndpoint = deliveryEndpoint
        
        showLoginProgressBar(flag: false)
        setAllButtons(flag: true)
        
        present(vc!, animated: true, completion: nil)
    }
    
    func savePreferences() {
        UserDefaults.standard.set(self.serverURITextField.text, forKey: "serverUrl")
        UserDefaults.standard.set(self.usernameTextField.text, forKey: "login")
        UserDefaults.standard.set(self.passwordTextField.text, forKey: "password")
    }
    
    func clearPreferences() {
        UserDefaults.standard.set("", forKey: "serverUrl")
        UserDefaults.standard.set("", forKey: "login")
        UserDefaults.standard.set("", forKey: "password")
    }
    
    func setAllButtons(flag: Bool) {
        usernameTextField.isEnabled = flag
        passwordTextField.isEnabled = flag
        loginButton.isEnabled = flag
    }
    
    @IBAction func loginButtonClickHandler(_ sender: Any) {
        let loginClass = Login(myServerURI: serverURITextField.text ?? "", myLogin: usernameTextField.text ?? "", myPassword: passwordTextField.text ?? "", saveCredentialsChecked: false, myLoginDelegate: self)
        loginClass.handleLogin()
    }
}
