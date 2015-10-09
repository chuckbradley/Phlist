//
//  ListDetailViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 8/16/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit
import Foundation
import Parse
import CoreData


class ListDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    var list:List!
    let model = ModelController.one
    var users = [String]()
    var invitees = [String]()

    var tapAwayRecognizer: UITapGestureRecognizer? = nil

    @IBOutlet weak var usersTable: UITableView!
    @IBOutlet weak var inviteesTable: UITableView!
    @IBOutlet weak var listNameLabel: UILabel!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var inviteButton: UIButton!

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "List Info"
        listNameLabel.text = list.title

        emailField.delegate = self
        usersTable.delegate = self
        inviteesTable.delegate = self

        tapAwayRecognizer = UITapGestureRecognizer(target: self, action: "tapAway:")

        setFontName("OpenSans", forView: self.view, andSubViews: true)
        setFontName("Menlo-Regular", forView: emailField, andSubViews: false)

        loadUsers()
    }


    // MARK: - Actions
    
    @IBAction func tapInviteButton(sender: AnyObject) {
        sendInvite()
    }

    func tapAway(recognizer: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    
    // MARK: - Cloud Interaction

    func loadUsers() {
        if let cloudList = list.cloudObject {
            populateTables(cloudList)
        }
        model.updateParseListForList(list) {
            cloudList, error in
            if let cloudList = cloudList {
                self.populateTables(cloudList)
            } else if error != nil {
                if error!.code == 100 {
                    print("loadUsers: connectivity error")
                    self.displayModalWithMessage("There is no network connection. Try again later.", andTitle: "Error")
                } else {
                    print("loadUsers: error")
                    self.displayModalWithMessage("There was some sort of problem. Try again later.", andTitle: "Error")
                }
            }
        }
    }


    func populateTables(cloudList:PFObject) {
        guard let users = cloudList["acceptedBy"] as? [String] else { return }
        guard let editors = cloudList["editors"] as? [String] else { return }
        self.users = users
        let editorSet = Set(editors)
        let inviteeSet = editorSet.exclusiveOr(Set(self.users))
        self.invitees = Array(inviteeSet)
        self.usersTable.reloadData()
        self.inviteesTable.reloadData()
    }


    func sendInvite() {
        let email = emailField.text!
        self.view.endEditing(true)
        emailField.text = ""
        model.inviteAddress(email, forList: list) {
            success, error in
            if success {
                self.invitees.append(email)
                self.inviteesTable.reloadData()
            } else if error != nil {
                print("sendInvite error: \(error!.description)")
                self.displayModalWithMessage("The invitation couldn't be sent. Try again later.", andTitle: "Error")
            }
        }
    }

    
    // MARK: - text field delegate methods
    
    func textFieldDidBeginEditing(textField: UITextField) {
        self.view.addGestureRecognizer(tapAwayRecognizer!)
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        self.view.removeGestureRecognizer(tapAwayRecognizer!)
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        sendInvite()
        return true
    }
    

    // MARK: - Table View delegate methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == inviteesTable {
            return invitees.count
        } else {
            return users.count
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if tableView == inviteesTable {
            let cell = tableView.dequeueReusableCellWithIdentifier("InviteeCell", forIndexPath: indexPath) 
            self.configureInviteeCell(cell, atIndexPath: indexPath)
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("UserCell", forIndexPath: indexPath) 
            self.configureUserCell(cell, atIndexPath: indexPath)
            return cell
        }
    }
    
    func configureUserCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let email = users[indexPath.row] as String
        cell.textLabel!.text = email
        setFontName("Menlo-Regular", forView: cell, andSubViews: true)
    }

    func configureInviteeCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let email = invitees[indexPath.row] as String
        cell.textLabel!.text = email
        setFontName("Menlo-Regular", forView: cell, andSubViews: true)
    }


    // MARK: - Utility
    
    func displayModalWithMessage(message: String, andTitle title: String?) {
        let alertController: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil) )
        self.presentViewController(alertController, animated: true, completion: nil)
    }


}
