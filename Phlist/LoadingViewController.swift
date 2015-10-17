//
//  LoadingViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 8/8/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit
import Foundation
import CoreData


class LoadingViewController: UIViewController {

    let model = ModelController.one

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.startAnimating()
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
            self.proceedToWelcome()
        }
    }

    func proceedToApp() {
        performSegueWithIdentifier("showNavigationView", sender: self)
    }

    func proceedToWelcome() {
        performSegueWithIdentifier("showWelcome", sender: self)
    }

}

