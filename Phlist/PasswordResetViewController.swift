//
//  PasswordResetViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 10/2/15.
//  Copyright © 2015 FreedomMind. All rights reserved.
//

import Foundation
import UIKit
import CoreData


class PasswordResetViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var messageTextView: UITextView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    var tapAwayRecognizer: UITapGestureRecognizer? = nil
    let model = ModelController.one
    var fromLogin = false


    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        emailField.attributedPlaceholder = NSAttributedString(string:"email",
            attributes:[NSForegroundColorAttributeName: UIColor.whiteColor()])
        tapAwayRecognizer = UITapGestureRecognizer(target: self, action: "tapAway:")

        setFontName("OpenSans", forView: self.view, andSubViews: true)
    }


    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.view.addGestureRecognizer(tapAwayRecognizer!)
        activityIndicator.hidden = true
        emailField.becomeFirstResponder()
    }


    // MARK: - Actions

    @IBAction func tapRequestResetButton(sender: AnyObject) {
        requestReset()
    }

    @IBAction func tapCancelButton(sender: AnyObject) {
        self.view.endEditing(true)
        if fromLogin {
            returnToLogin()
        } else {
            returnToWelcome()
        }
    }

    @IBAction func tapReturnToLoginButton(sender: AnyObject) {
        returnToLogin()
    }


    func tapAway(recognizer: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }


    // MARK: - Operations

    func returnToLogin() {
        let controller = self.storyboard!.instantiateViewControllerWithIdentifier("Login") as! LoginViewController
        self.presentViewController(controller, animated: true, completion: nil)
    }

    func returnToWelcome() {
        let controller = self.storyboard!.instantiateViewControllerWithIdentifier("Welcome") as! WelcomeViewController
        self.presentViewController(controller, animated: true, completion: nil)
    }

    func requestReset() {
        self.messageTextView.text = ""
        self.view.endEditing(true)
        activityIndicator.hidden = false
        activityIndicator.startAnimating()

        let email = emailField.text!

        print("\nRequested password reset for \(email)")

        model.requestPasswordResetForEmailInBackground(email) {
            success, error in

            self.messageTextView.text = ""
            self.activityIndicator.hidden = true
            self.activityIndicator.stopAnimating()

            guard success else {
                // The login failed. Check error to see why.
                guard let error = error else {
                    print("password reset request failed")
                    self.displayMessage("Error: Request failed unexpectedly. Please try again later.")
                    return
                }
                var errorString = error.userInfo["error"] as! NSString
                let errorCode = error.userInfo["code"] as! Int
                if errorCode == 100 {
                    errorString = "Darn! No network connection"
                } else if errorCode == 101 {
                    errorString = "Can't find that account. Double-check your email."
                } else if errorCode == 200 {
                    errorString = "Oops! You're missing your email"
                } else if errorCode == 204 {
                    errorString = "Oops! You're missing your email."
                } else if errorCode == 205 {
                    errorString = "Oops. Can't find that account. Double-check your email."
                } else if errorCode == 125 {
                    errorString = "Oops! That's not a valid email."
                } else {
                    errorString = "Error: Request failed. Please try again later."
                }
                // Show the errorString somewhere and let the user try again.
                print("\nerror code = \(errorCode)")
                self.displayMessage("\(errorString)")
                return
            }
            // after request has successfully submitted, return user to login screen
            self.displayMessage("Check your email app for instructions to reset your password.\nOnce you have completed the reset, you can log in.")
        }
    }


    // MARK: - Text field delegate

    func textFieldDidBeginEditing(textField: UITextField) {
        displayMessage("")
    }


    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if !textField.text!.isEmpty {
            requestReset()
        }
        return true
    }


    // MARK: - Utilities

    func displayMessage(errorString: String) {
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

