//
//  LoginViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/26/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit
import Foundation
import Parse
import CoreData


class LoginViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var messageTextView: UITextView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var tapAwayRecognizer: UITapGestureRecognizer? = nil
    let model = ModelController.one

    override func viewDidLoad() {
        super.viewDidLoad()
        emailField.attributedPlaceholder = NSAttributedString(string:"email",
            attributes:[NSForegroundColorAttributeName: UIColor.whiteColor()])
        passwordField.attributedPlaceholder = NSAttributedString(string:"password",
            attributes:[NSForegroundColorAttributeName: UIColor.whiteColor()])
        
        tapAwayRecognizer = UITapGestureRecognizer(target: self, action: "tapAway:")

        // example of observer for NETWORK_STATUS_NOTIFICATION
        // NSNotificationCenter.defaultCenter().addObserver(self, selector: "connectivityChanged", name: NETWORK_STATUS_NOTIFICATION, object: nil)
    }
    
//    func connectivityChanged() {
//        println("LoginViewController.connectivityChanged to \(connectivityStatus)")
//    }
//
//    deinit {
//        NSNotificationCenter.defaultCenter().removeObserver(self, name: NETWORK_STATUS_NOTIFICATION, object: nil)
//    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.view.addGestureRecognizer(tapAwayRecognizer!)
        activityIndicator.hidden = true
        emailField.becomeFirstResponder()
    }
    
    
    @IBAction func loginButtonTouch(sender: AnyObject) {
        if emailField.text.isEmpty || passwordField.text.isEmpty {
            notify("Please enter both your email and password.")
        } else {
            attemptLogin()
        }
    }
    
    
    
    @IBAction func signupButtonTouch(sender: AnyObject) {
        if emailField.text.isEmpty || passwordField.text.isEmpty {
            notify("Go ahead and enter your email and desired password.")
        } else {
            attemptSignup()
        }
    }
    
    
    func attemptSignup() {
        self.view.endEditing(true)
        activityIndicator.hidden = false
        activityIndicator.startAnimating()

        let email = emailField.text!
        let password = passwordField.text!
        println("\nSign up: email=\(email), password=\(password)")
    
        var user = PFUser()
        user.username = email
        user.email = email
        user.password = password

        user.signUpInBackgroundWithBlock {
            (succeeded: Bool, error: NSError?) -> Void in
            self.activityIndicator.hidden = true
            self.activityIndicator.stopAnimating()
            if let error = error {
                var errorString = error.userInfo!["error"] as! NSString
                let errorCode = error.userInfo!["code"] as! Int
                if errorCode == 100 {
                    errorString = "Error: No network connection"
                } else if errorCode == 101 {
                    errorString = "Can't find that account. Double-check your email and password."
                } else if errorCode == 200 {
                    errorString = "Oops! You're missing your email."
                } else if errorCode == 201 {
                    errorString = "Oops! You're missing your password."
                } else if errorCode == 202 {
                    errorString = "Sorry, that email is already taken."
                } else if errorCode == 203 {
                    errorString = "Sorry, that email is already taken."
                } else if errorCode == 204 {
                    errorString = "Oops! You're missing your email"
                } else if errorCode == 125 {
                    errorString = "Oops! That's not a valid email."
                } else {
                    errorString = "Error: Signup failed"
                }
                // Show the errorString somewhere and let the user try again.
                println("\nerror code = \(errorCode)")
                self.displayError("\(errorString)")
            } else {
                // Hooray! Let them use the app now.
                self.model.user = User(parseUserObject: user, context: self.model.context)
                self.model.save()
                self.proceedToApp()
            }
        }
    }


    func attemptLogin() {
        self.messageTextView.text = ""
        self.view.endEditing(true)
        activityIndicator.hidden = false
        activityIndicator.startAnimating()

        // populate Parse login
        let email = emailField.text!
        let password = passwordField.text!
        println("\nLogin: email=\(email), password=\(password)")

        PFUser.logInWithUsernameInBackground(email, password: password) {
            (user: PFUser?, error: NSError?) -> Void in
            self.messageTextView.text = ""
            if user != nil {
                // Do stuff after successful login.
                self.model.user = User(parseUserObject: user!, context: self.model.context)
                self.model.save()
                self.proceedToApp()
            } else {
                // The login failed. Check error to see why.
                if let error = error {
                    self.activityIndicator.hidden = true
                    self.activityIndicator.stopAnimating()
                    var errorString = error.userInfo!["error"] as! NSString
                    let errorCode = error.userInfo!["code"] as! Int
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
                    println("\nerror code = \(errorCode)")
                    self.displayError("\(errorString)")
                } else {
                    println("no user or error")
                }
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
    
    func tapAway(recognizer: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    

    
    /* text field delegate methods */
    
    func textFieldDidBeginEditing(textField: UITextField) {
        displayError("")
    }
    
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            if !emailField.text.isEmpty && !passwordField.text.isEmpty {
                attemptLogin()
            }
        }
        return true
    }

    
}

