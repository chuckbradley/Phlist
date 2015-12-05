//
//  AllListsViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/12/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit
import CoreData

class AllListsViewController: UITableViewController, NSFetchedResultsControllerDelegate, UITextFieldDelegate {

    let model = ModelController.one
    
    var firstAppearance = false

    @IBOutlet var listTable: UITableView!
    @IBOutlet weak var logoutButton: UIBarButtonItem!
    @IBOutlet weak var editButton: UIBarButtonItem!


    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        firstAppearance = true

        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "tapAddButton:")
        self.navigationItem.rightBarButtonItem = addButton

        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()

        self.refreshControl!.addTarget(self, action: "pulledTable:", forControlEvents: UIControlEvents.ValueChanged)

        buildListAdditionUI()
        if !model.isClouded {
            logoutButton.title = "Sign up"
        }

        setFontName("OpenSans", forView: self.view, andSubViews: true)

        fetchedResultsController.delegate = self

    }

    override func viewWillAppear(animated: Bool) {
        if firstAppearance { // no need for re-sync on first appearance
            handleResults()
        } else {
            refreshList()
        }
    }


    // MARK: - Actions

    func tapAddButton(sender: AnyObject) {
        displayListAdditionPanel()
    }

    func tapAddNewListButton(sender:UIButton!) {
        addNewList()
    }

    @IBAction func tapLogoutButton(sender: AnyObject) {
        if model.isClouded {
            model.logout(self)
        } else {
            performSegueWithIdentifier("showSignupFromAllLists", sender: self)
        }
    }

    @IBAction func tapEditButton(sender: UIBarButtonItem) {
        if self.editing {
            self.editing = false
            editButton.title = "Edit"
            // TODO: save changes
        } else {
            self.editing = true
            editButton.title = "Done"
        }
    }

    @IBAction func tapRefreshButton(sender: AnyObject) {
        refreshList()
    }

    func pulledTable(sender: AnyObject) {
        refreshList()
    }

    func showList() {
        performSegueWithIdentifier("showList", sender: self)
    }


    // MARK: - Segue preparation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showList" {
            guard let indexPath = self.tableView.indexPathForSelectedRow else { return }
            guard let list = self.fetchedResultsController.objectAtIndexPath(indexPath) as? List else { return }
            let controller = segue.destinationViewController as! ListItemsViewController
            controller.list = list
        }
    }


    // MARK: - Content

    func refreshList() {
        model.syncLists {
            success, error in
            if error == nil {
                self.handleResults()
            } else {
                self.refreshControl?.endRefreshing()
            }
        }
    }


    func handleResults() {
        firstAppearance = false
        do {
            try self.fetchedResultsController.performFetch()
        } catch _ {
            print("refreshList: error performing fetch")
        }
        self.listTable.reloadData()

        if self.model.invitations.isEmpty {
            self.refreshControl?.endRefreshing()
        } else {
            // handle invitations, if any
            self.model.confirmInvitationsFromController(self) {
                confirmed in
                if confirmed {
                    do {
                        try self.fetchedResultsController.performFetch()
                    } catch _ {
                        print("refreshList: error performing fetch")
                    }
                }
                self.listTable.reloadData()
                self.refreshControl?.endRefreshing()
            }
        }
        
    }



    // MARK: - Fetched results controller

    lazy var fetchedResultsController: NSFetchedResultsController = {

        let fetchRequest = NSFetchRequest(entityName: "List")

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let noDeletedListPredicate = NSPredicate(format: "toBeDeleted == %@", false) // don't include toBeDeleted

        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [noDeletedListPredicate])
        
        fetchRequest.predicate = compoundPredicate

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.model.context,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()


    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }

    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
            case .Insert:
                self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
            case .Delete:
                self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
            default:
                return
        }
    }

    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
        case .Update:
            self.configureCell(tableView.cellForRowAtIndexPath(indexPath!)!, atIndexPath: indexPath!)
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        }
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }

    
    
    // MARK: - Table View
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) 
        self.configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
        
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        let list = fetchedResultsController.objectAtIndexPath(indexPath) as! List

        if editingStyle == .Delete {
            model.confirmRemovalOfList(list, fromController: self) {
                confirmed in
                if confirmed {
                    self.model.removeList(list, handler: nil)
                }
            }
        }
    }


    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let list = self.fetchedResultsController.objectAtIndexPath(indexPath) as! List
        model.assignCloudObjectToList(list) { // try to get cloudList for selected list
            cloudList, error in
            if cloudList != nil {
                // if so, synchronize list items with those from cloudList before showing list
                self.model.syncItemsInList(list) {
                    success, error in
                    self.showList()
                }
            } else { // otherwise, just show list with stored items
                self.showList()
            }
        }
    }


    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let list = self.fetchedResultsController.objectAtIndexPath(indexPath) as! List
        cell.textLabel!.text = list.title
        setFontName("OpenSans", forView: cell.textLabel!, andSubViews: false)
    }



    // MARK: - List Addition UI

    var listAdditionPanel: UIView?
    var addNewListButton: UIButton?
    var newListNameField: UITextField?
    var dismissalPanel: UIView?

    func buildListAdditionUI() {
        dismissalPanel = UIView(frame: CGRectMake(0, 0, view.bounds.width, view.bounds.height))
        dismissalPanel!.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.0)
        dismissalPanel!.hidden = true
        self.view.addSubview(dismissalPanel!)

        // create panel
        listAdditionPanel = UIView(frame: CGRectMake(0, -350, view.bounds.width, 54))
        listAdditionPanel!.backgroundColor=UIColor.orangeColor()

        // create text field
        newListNameField = UITextField()
        newListNameField!.frame = CGRectMake(12, 12, view.bounds.width-86, 30)
        newListNameField!.backgroundColor = UIColor.whiteColor()
        newListNameField!.layer.cornerRadius = 6
        newListNameField!.textInputView.layoutMargins.left = 12.0
        newListNameField!.placeholder = "Name for new list"

        // define padding view within text field
        let paddingView = UIView(frame: CGRectMake(0, 0, 8, newListNameField!.frame.height))
        newListNameField!.leftView = paddingView
        newListNameField!.leftViewMode = UITextFieldViewMode.Always
        newListNameField!.returnKeyType = .Done
        newListNameField!.delegate = self

        // create button
        addNewListButton = UIButton(type: .System)
        addNewListButton!.backgroundColor = UIColor.blackColor()
        addNewListButton!.setTitle("Add", forState: UIControlState.Normal)
        addNewListButton!.frame = CGRectMake(view.bounds.width-62, 12, 50, 30)
        addNewListButton!.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        addNewListButton!.addTarget(self, action: "tapAddNewListButton:", forControlEvents: UIControlEvents.TouchUpInside)

        // add field and button to panel and panel to parent view
        listAdditionPanel!.addSubview(newListNameField!)
        listAdditionPanel!.addSubview(addNewListButton!)
        self.view.addSubview(listAdditionPanel!)

    }

    func addNewList() {
        var newListName = ""
        if newListNameField!.text != nil {
            newListName = newListNameField!.text!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        }
        if !newListName.isEmpty {
            model.addListWithTitle(newListName)
        }
        dismissListAdditionPanel()
    }

    func displayListAdditionPanel() {
        self.dismissalPanel!.hidden = false
        UIView.animateWithDuration(0.4,
            animations: {
                self.listAdditionPanel!.frame.origin.y = 0
                self.dismissalPanel!.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.75)
            },
            completion: {
                _ in
                self.dismissalPanel!.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "dismissListAdditionPanel"))
                self.newListNameField?.becomeFirstResponder()

        })
    }

    func dismissListAdditionPanel() {
        self.newListNameField!.resignFirstResponder()
        UIView.animateWithDuration(0.4,
            animations: {
                self.listAdditionPanel!.frame.origin.y = -350
                self.dismissalPanel!.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.0)
            },
            completion: {
                _ in
                self.newListNameField!.text = ""
                self.dismissalPanel!.hidden = true
        })
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        addNewList()
        return true
    }

}

