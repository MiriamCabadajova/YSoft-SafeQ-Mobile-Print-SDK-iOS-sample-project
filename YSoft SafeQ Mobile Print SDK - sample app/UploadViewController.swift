//
//  UploadViewController.swift
//  YSoft SafeQ Mobile Print SDK - sample app
//
//  Created by Miriam Cabadajová on 15/04/2020.
//  Copyright © 2020 Y Soft Corporation, a.s. All rights reserved.
//

import UIKit

protocol UploadViewControllerDelegate {
    func add(printJob: PrintJob)
}

class UploadViewController: UIViewController, UploadDelegate {
    var serverURI = ""
    var token = ""
    var deliveryEndpoint: DeliveryEndpoint = .mig
    let CELL_REUSE_IDENTIFIER = "cellReuseID"
    var counter = 1
    private var printJobsArray: Array<PrintJob> = Array()
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addFileButton: UIButton!
    @IBOutlet weak var uploadButton: UIButton!
    
    @IBAction func addButtonHandler(_ sender: Any) {
        let file = createGenericFile()
        let newJob = PrintJob(url: URL(fileURLWithPath: file))
        add(printJob: newJob)
    }
    
    @IBAction func uploadButtonHandler(_ sender: Any) {
        let uploadClass = Upload(myServerURI: serverURI, myPrintJobs: printJobsArray, myDeliveryEndpoint: deliveryEndpoint, myToken: token, myUploadDelegate: self)
        uploadClass.handleUpload()
    }
    
    func createGenericFile() -> String {
        let homeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileManager = FileManager.default
        let newFile = homeURL.appendingPathComponent("test_file_\(counter).txt").path
        counter += 1
         
        if(!fileManager.fileExists(atPath:newFile)){
           fileManager.createFile(atPath: newFile, contents: nil, attributes: nil)
        }
        print(newFile)
        return newFile
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
    }
    
    func isUploadBeingProcessed(flag: Bool) {
        if flag {
            tableView.isUserInteractionEnabled = false
            addFileButton.isEnabled = false
            uploadButton.isEnabled = false
            uploadButton.setTitle("Uploading...", for: .normal)
            
        } else {
            tableView.isUserInteractionEnabled = true
            uploadButton.setTitle("Upload", for: .normal)
        }
    }
    
    func selectBtnIsVisible(flag: Bool) {
        // enable add file btn if needed
        addFileButton.isEnabled = flag
    }
    
    func notifyUser(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func reloadTableview(printJobs: Array<PrintJob>) {
        printJobsArray = printJobs
        tableView.reloadData()
    }
}

extension UploadViewController: UploadViewControllerDelegate {
    func add(printJob: PrintJob) {
        printJobsArray.append(printJob)
        tableView.reloadData()
    }
}

extension UploadViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if printJobsArray.count > 0 {
            uploadButton.isEnabled = true
        } else {
            uploadButton.isEnabled = false
        }
        return printJobsArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CELL_REUSE_IDENTIFIER, for: indexPath) as UITableViewCell
        cell.textLabel?.text = printJobsArray[indexPath.item].url.lastPathComponent
        return cell
    }
}
