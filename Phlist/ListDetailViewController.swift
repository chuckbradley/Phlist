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


class ListDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var list:List!
    let model = ModelController.one
    var users = [String]()
    var invitees = [String]()

    @IBOutlet weak var usersTable: UITableView!
    @IBOutlet weak var inviteesTable: UITableView!
    @IBOutlet weak var listNameLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "List Details"
        
        usersTable.delegate = self
        inviteesTable.delegate = self
        
        listNameLabel.text = list.title

    }


    // MARK: - Table View
    
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
            let cell = tableView.dequeueReusableCellWithIdentifier("InviteeCell", forIndexPath: indexPath) as! UITableViewCell
            self.configureInviteeCell(cell, atIndexPath: indexPath)
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("UserCell", forIndexPath: indexPath) as! UITableViewCell
            self.configureUserCell(cell, atIndexPath: indexPath)
            return cell
        }
    }
    
    func configureUserCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let email = users[indexPath.row] as String
        cell.textLabel!.text = email
    }

    func configureInviteeCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let email = invitees[indexPath.row] as String
        cell.textLabel!.text = email
    }







}