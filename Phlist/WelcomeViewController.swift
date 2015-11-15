//
//  WelcomeViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 9/30/15.
//  Copyright © 2015 FreedomMind. All rights reserved.
//

import UIKit

class WelcomeViewController: UIViewController {

    let model = ModelController.one

    override func viewDidLoad() {
        super.viewDidLoad()

        setFontName("OpenSans", forView: self.view, andSubViews: true)

    }

    @IBAction func tapSkipSignupButton(sender: AnyObject) {
        model.isClouded = false
        let controller = self.storyboard!.instantiateViewControllerWithIdentifier("NavigationController") as! UINavigationController
        self.presentViewController(controller, animated: true, completion: nil)
    }


}

