//
//  LoginViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/26/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit
import Foundation
import CoreData


class LoginViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var messageTextView: UITextView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var tapAwayRecognizer: UITapGestureRecognizer? = nil
    let model = ModelController.one


    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        emailField.attributedPlaceholder = NSAttributedString(string:"email",
            attributes:[NSForegroundColorAttributeName: UIColor.whiteColor()])
        passwordField.attributedPlaceholder = NSAttributedString(string:"password",
            attributes:[NSForegroundColorAttributeName: UIColor.whiteColor()])
        
        tapAwayRecognizer = UITapGestureRecognizer(target: self, action: #selector(LoginViewController.tapAway(_:)))

        setFontName("OpenSans", forView: self.view, andSubViews: true)

    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.view.addGestureRecognizer(tapAwayRecognizer!)
        activityIndicator.hidden = true
        emailField.becomeFirstResponder()
    }
    

    // MARK: - Actions

    @IBAction func loginButtonTouch(sender: AnyObject) {
        if emailField.text!.isEmpty || passwordField.text!.isEmpty {
            notify("Please enter both your email and password.")
        } else {
            attemptLogin()
        }
    }

    @IBAction func tapCancelButton(sender: AnyObject) {
        self.view.endEditing(true)
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    func tapAway(recognizer: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }


    // MARK: - Operations

    func attemptLogin() {
        self.messageTextView.text = ""
        self.view.endEditing(true)
        activityIndicator.hidden = false
        activityIndicator.startAnimating()

        let email = emailField.text!
        let password = passwordField.text!

        model.logIn(email, password: password) {
            success, error in
            self.messageTextView.text = ""
            self.activityIndicator.hidden = true
            self.activityIndicator.stopAnimating()
            if success {
                self.proceedToApp()
            } else if error == nil {
                print("no user or error")
                self.displayError("Error: Login failed unexpectedly. Try again later.")
                return
            } else {
                var errorString = error!.userInfo["error"] as! NSString
                let errorCode = error!.code
                // let errorCode = error!.userInfo["code"] as! Int
                if errorCode == 100 {
                    errorString = "Darn! No network connection"
                } else if errorCode == 101 {
                    errorString = "Can't find that account. Double-check your email and password."
                } else if errorCode == 200 {
                    errorString = "Oops! You're missing your email"
                } else if errorCode == 201 {
                    errorString = "Oops! You're missing your password."
                } else if errorCode == 204 {
                    errorString = "Oops! You're missing your email."
                } else if errorCode == 205 {
                    errorString = "Oops. Can't find that account. Double-check your email."
                } else if errorCode == 125 {
                    errorString = "Oops! That's not a valid email."
                } else {
                    errorString = "Error: Login failed"
                }
                // Show the errorString somewhere and let the user try again.
                print("\nerror code = \(errorCode)")
                self.displayError("\(errorString)")
                return
            }
        }
    }


    func proceedToApp() {
        model.syncLists {
            success, error in
            self.activityIndicator.hidden = true
            self.activityIndicator.stopAnimating()
            let controller = self.storyboard!.instantiateViewControllerWithIdentifier("NavigationController") as! UINavigationController
            self.presentViewController(controller, animated: true, completion: nil)
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showResetPassword" {
            let controller = segue.destinationViewController as! PasswordResetViewController
            controller.fromLogin = true
        }
    }


    // MARK: - Text field delegate
    
    func textFieldDidBeginEditing(textField: UITextField) {
        displayError("")
    }
    
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            if !emailField.text!.isEmpty && !passwordField.text!.isEmpty {
                attemptLogin()
            }
        }
        return true
    }

    // MARK: - Utilities

    func displayError(errorString: String) {
        self.activityIndicator.hidden = true
        self.activityIndicator.stopAnimating()
        self.messageTextView.text = errorString
    }

    func notify(message:String) {
        let alertController: UIAlertController = UIAlertController(title: nil, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil) )
        self.presentViewController(alertController, animated: true, completion: nil)
    }

}

