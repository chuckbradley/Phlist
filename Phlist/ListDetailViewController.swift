//
//  ListDetailViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 8/16/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit
import Foundation
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

        tapAwayRecognizer = UITapGestureRecognizer(target: self, action: #selector(ListDetailViewController.tapAway(_:)))

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
        model.loadUserGroupsForList(list) {
            userArrays, error in
            self.populateTableData((userArrays.users, userArrays.editors))
        }
        model.updateUserGroupsForList(list) {
            userArrays, error in
            if error != nil {
                if error!.code == 100 {
                    self.displayModalWithMessage("There is no network connection. Try again later.", andTitle: "Error")
                } else {
                    self.displayModalWithMessage("There was some sort of problem. Try again later.", andTitle: "Error")
                }
            } else {
                self.populateTableData((userArrays.users, userArrays.editors))
            }
        }

    }

    func populateTableData(userArrays: (users:[String], invitees:[String])) {
        self.users = userArrays.users
        self.invitees = userArrays.invitees
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

        let cell = tableView == inviteesTable ?
            tableView.dequeueReusableCellWithIdentifier("InviteeCell", forIndexPath: indexPath) :
            tableView.dequeueReusableCellWithIdentifier("UserCell", forIndexPath: indexPath)

        let email = tableView == inviteesTable ?
            (invitees[indexPath.row] as String) :
            (users[indexPath.row] as String)

        cell.textLabel!.text = email
        setFontName("Menlo-Regular", forView: cell, andSubViews: true)

        return cell
    }



    // MARK: - Utility
    
    func displayModalWithMessage(message: String, andTitle title: String?) {
        let alertController: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil) )
        self.presentViewController(alertController, animated: true, completion: nil)
    }


}
