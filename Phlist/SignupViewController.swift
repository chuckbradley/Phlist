//
//  SignupViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 9/30/15.
//  Copyright © 2015 FreedomMind. All rights reserved.
//

import Foundation
import UIKit
import CoreData


class SignupViewController: UIViewController, UITextFieldDelegate {

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

        tapAwayRecognizer = UITapGestureRecognizer(target: self, action: #selector(SignupViewController.tapAway(_:)))

        setFontName("OpenSans", forView: self.view, andSubViews: true)

    }


    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.view.addGestureRecognizer(tapAwayRecognizer!)
        activityIndicator.hidden = true
        emailField.becomeFirstResponder()
    }


    // MARK: - Actions

    @IBAction func signupButtonTouch(sender: AnyObject) {
        if emailField.text!.isEmpty || passwordField.text!.isEmpty {
            notify("Go ahead and enter your email and desired password.")
        } else {
            attemptSignup()
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

    func attemptSignup() {
        self.view.endEditing(true)
        activityIndicator.hidden = false
        activityIndicator.startAnimating()

        model.signUp(emailField.text!, password: passwordField.text!) {
            success, error in
            self.activityIndicator.hidden = true
            self.activityIndicator.stopAnimating()
            if success {
                self.proceedToApp()
            } else if error == nil {
                print("unsuccessful, but no reported error")
                self.displayError("Error: Signup failed. Try again later.")
            } else {
                var errorString = error!.userInfo["error"] as! NSString
                let errorCode = error!.code
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
                // Show the errorString and let the user try again.
                print("\nerror code = \(errorCode)")
                self.displayError("\(errorString)")
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
                attemptSignup()
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

