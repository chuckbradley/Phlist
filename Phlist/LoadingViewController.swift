//
//  LoadingViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 8/8/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit
import Foundation
import Parse
import CoreData


class LoadingViewController: UIViewController {

    let model = ModelController.one

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.startAnimating()
        
        // example of observer for NETWORK_STATUS_NOTIFICATION
        // NSNotificationCenter.defaultCenter().addObserver(self, selector: "connectivityChanged", name: NETWORK_STATUS_NOTIFICATION, object: nil)
    }

    override func viewDidAppear(animated: Bool) {
        if model.userIsValid() {
            model.syncLists {
                success, error in
                self.activityIndicator.stopAnimating()
                self.proceedToApp()
            }
        } else {
            self.activityIndicator.stopAnimating()
            self.proceedToLogin()
        }
    }

    func proceedToApp() {
        performSegueWithIdentifier("showNavigationView", sender: self)
    }

    func proceedToLogin() {
        performSegueWithIdentifier("showLogin", sender: self)
    }
    
    func alert(message:String) {
        let alertController: UIAlertController = UIAlertController(title: nil, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default) { action in })
        self.presentViewController(alertController, animated: true, completion: nil)
    }

    
//    func connectivityChanged() {
//        println("LoadingViewController.connectivityChanged to \(connectivityStatus)")
//    }
//    
//    deinit {
//        NSNotificationCenter.defaultCenter().removeObserver(self, name: NETWORK_STATUS_NOTIFICATION, object: nil)
//    }

}

