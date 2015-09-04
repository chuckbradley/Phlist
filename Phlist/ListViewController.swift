//
//  ListViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/19/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit
import CoreData
import Parse

class ListViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    let model = ModelController.one
    var list: List!

    @IBOutlet var listTable: UITableView!

    // temporary add-item method
    var newItemPanel: UIView?
    var addNewListButton: UIButton?
    var newListNameField: UITextField?
    var dismissalPanel: UIView?

        
    override func viewDidLoad() {
        super.viewDidLoad()

        // navigation & toolbar:
        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "tapAddButton:")
        self.navigationItem.rightBarButtonItem = addButton
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        
        self.title = list.title
        populateListParseObject()

        fetchedResultsController.performFetch(nil)

        fetchedResultsController.delegate = self
        println("ListView sections count = \(fetchedResultsController.sections?.count)")

        // temporary add-item UI
        buildNewItemUI()

    }
    

    func populateListParseObject() {
        if list.parseObject == nil && connectivityStatus != NOT_REACHABLE && list.parseID != nil {
            var query = PFQuery(className:"List")
            query.getObjectInBackgroundWithId(list.parseID!) {
                pfList, error in
                if pfList != nil {
                    self.list.parseObject = pfList!
                }
            }
        }
    }
    

    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow() {
                let object = self.fetchedResultsController.objectAtIndexPath(indexPath) as! ListItem
                let destination = segue.destinationViewController as! DetailViewController
                destination.listItem = object
            }
        }
    }
    
    // MARK: - Table View
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        println("section count = \(self.fetchedResultsController.sections?.count)")
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // assign title
        // section.description returns "0" for Active and "1" for Archived
        if section.description == "0" { return "Active" }
        else { return "Archived" }
//        return section.description
        // let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        // sectionInfo.indexTitle returns index of title ("A" for "Active", etc.)
        // sectionInfo.name returns value found by sectionNameKeyPath (activityState)
        // section.value returns an Opaque Value
        // section.description returns string of first sortDescriptor
        // println("section.value = \(section.value) and section.description = \(section.description)")
        // println("section name = \(sectionInfo.name) and indexTitle = \(sectionInfo.indexTitle)")
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        println("section \(section.description) number of rows = \(sectionInfo.numberOfObjects)")
        return sectionInfo.numberOfObjects
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! UITableViewCell
        self.configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let context = self.fetchedResultsController.managedObjectContext
            context.deleteObject(self.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject)
            
            var error: NSError? = nil
            if !context.save(&error) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                //println("Unresolved error \(error), \(error.userInfo)")
                abort()
            }
        }
    }
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let listItem = self.fetchedResultsController.objectAtIndexPath(indexPath) as! ListItem
        cell.textLabel!.text = listItem.name
        if !listItem.active {
            cell.textLabel!.tintColor = UIColor.lightGrayColor()
        }
        // TODO: get image info
            
    }
    
    // MARK: - Fetched results controller

    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "ListItem")

        // define sorting: first by active (for sectioning) then by creation date (within each section)
        let activeDescriptor = NSSortDescriptor(key: "active", ascending: true)
        let dateDescriptor = NSSortDescriptor(key: "creationDate", ascending: false)
        fetchRequest.sortDescriptors = [activeDescriptor, dateDescriptor]

        let parentListPredicate = NSPredicate(format: "list == %@", self.list);
        let noDeletedListPredicate = NSPredicate(format: "toBeDeleted == %@", false);
        let compoundPredicate = NSCompoundPredicate.andPredicateWithSubpredicates([parentListPredicate, noDeletedListPredicate])

        fetchRequest.predicate = compoundPredicate
//        fetchRequest.predicate = NSPredicate(format: "list == %@", self.list);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.model.context,
            sectionNameKeyPath: "activityState",
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
        default:
            return
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
    
    /*
    // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
    // In the simplest, most efficient, case, reload the table view.
    self.tableView.reloadData()
    }
    */
    
    

    
    // temporary solution - create text-entry field for adding new items

    // MARK: - Actions
    
    func tapAddButton(sender: AnyObject) {
        println("add button tapped")
        displayNewItemPanel()
    }
    
    func tapAddNewItemButton(sender:UIButton!) {
        let newItemName = newListNameField!.text
        println("new item name = \(newItemName)")
        model.addItemWithName(newItemName, toList: self.list!)
        listTable.reloadData()
        dismissNewItemPanel()
    }

    
    // MARK: - UI
    
    func displayNewItemPanel() {
        self.dismissalPanel!.hidden = false
        UIView.animateWithDuration(0.4,
            animations: {
                self.newItemPanel!.frame.origin.y = 20
                self.dismissalPanel!.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.75)
            },
            completion: {
                _ in
                self.dismissalPanel!.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "dismissNewItemPanel"))
                self.newListNameField?.becomeFirstResponder()
                
        })
    }
    
    
    func dismissNewItemPanel() {
        self.newListNameField!.resignFirstResponder()
        UIView.animateWithDuration(0.4,
            animations: {
                self.newItemPanel!.frame.origin.y = -250
                self.dismissalPanel!.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.0)
            },
            completion: {
                _ in
                self.newListNameField!.text = ""
                self.dismissalPanel!.hidden = true
        })
    }
    
    func buildNewItemUI() {
        dismissalPanel = UIView(frame: CGRectMake(0, 0, view.bounds.width, view.bounds.height))
        dismissalPanel!.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.0)
        dismissalPanel!.hidden = true
        self.view.addSubview(dismissalPanel!)
        
        // create panel
        newItemPanel = UIView(frame: CGRectMake(0, -250, view.bounds.width, 54))
        newItemPanel!.backgroundColor=UIColor.orangeColor()
        
        // create text field
        newListNameField = UITextField()
        newListNameField!.frame = CGRectMake(12, 12, view.bounds.width-86, 30)
        newListNameField!.backgroundColor = UIColor.whiteColor()
        newListNameField!.layer.cornerRadius = 6
        newListNameField!.textInputView.layoutMargins.left = 12.0
        newListNameField!.placeholder = "Name for new item"
        
        // define padding view within text field
        let paddingView = UIView(frame: CGRectMake(0, 0, 8, newListNameField!.frame.height))
        newListNameField!.leftView = paddingView
        newListNameField!.leftViewMode = UITextFieldViewMode.Always
        
        // create button
        addNewListButton = (UIButton.buttonWithType(.System) as! UIButton)
        addNewListButton!.backgroundColor = UIColor.blackColor()
        addNewListButton!.setTitle("Add", forState: UIControlState.Normal)
        addNewListButton!.frame = CGRectMake(view.bounds.width-62, 12, 50, 30)
        addNewListButton!.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        addNewListButton!.addTarget(self, action: "tapAddNewItemButton:", forControlEvents: UIControlEvents.TouchUpInside)
        
        // add field and button to panel and panel to parent view
        newItemPanel!.addSubview(newListNameField!)
        newItemPanel!.addSubview(addNewListButton!)
        self.view.addSubview(newItemPanel!)
        
    }
    

}

