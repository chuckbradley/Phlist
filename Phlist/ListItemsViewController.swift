//
//  ListItemsViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 8/12/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import Parse


class ListItemsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate, ListItemCellDelegate {

    var list:List!
    let model = ModelController.one

    @IBOutlet weak var tableView: UITableView!



    override func viewDidLoad() {
        super.viewDidLoad()

        // navigation & toolbar:
        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "tapPlusButton:")
        self.navigationItem.rightBarButtonItem = addButton
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()

        self.title = list.title
        
        fetchedResultsController.delegate = self

        // temporary add-item UI
        buildAddNewItemUI()

        model.assignParseObjectToList(list) {
            success, pfList, error in
            if pfList != nil {
                // syncronize items with cloud
                self.model.syncItemsInList(self.list) {
                    success, error in // are parameters even needed?
                    self.fetchedResultsController.performFetch(nil)
                    self.tableView.reloadData()
                }
            } else {
                // just use locally stored items
                self.fetchedResultsController.performFetch(nil)
                self.tableView.reloadData()
            }
        }
    }


    override func viewDidLayoutSubviews() {
        addNewItemPanelDismisser!.cancelsTouchesInView = false
    }
    


    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow() {
//                let object = self.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject
                let destination = segue.destinationViewController as! DetailViewController
//                destination.detailItem = object
                let item = self.fetchedResultsController.objectAtIndexPath(indexPath) as! ListItem
                destination.listItem = item
            }
        }
        if segue.identifier == "showItemDetail" {
            let destination = segue.destinationViewController as! DetailViewController
            if let item = self.selectedItem {
                destination.listItem = item
            }
//            destination.listItem = fetchedResultsController.fetchedObjects?[0] as? ListItem
        }
    }


    // MARK: - Table View
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title = "Archived"

        // section.description returns "0" for first and "1" for second
        if section.description == "0" {
            if let firstItem = fetchedResultsController.fetchedObjects?[0] as? ListItem {
                if firstItem.active {
                    title = "Active"
                }
            }
        }
        return title

        // FYI:
        // let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        // sectionInfo.indexTitle returns index of title ("A" for "Active", etc.)
        // sectionInfo.name returns value found by sectionNameKeyPath (activityState)
        // section.value returns an Opaque Value
        // section.description returns string of first sortDescriptor
        // println("section.value = \(section.value) and section.description = \(section.description)")
        // println("section name = \(sectionInfo.name) and indexTitle = \(sectionInfo.indexTitle)")
    }


    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        return sectionInfo.numberOfObjects
    }


    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let listItem = self.fetchedResultsController.objectAtIndexPath(indexPath) as! ListItem
        if listItem.active {
            let cell = tableView.dequeueReusableCellWithIdentifier("ActiveCell", forIndexPath: indexPath) as! ActiveListItemCell
            self.configureActiveCell(cell, atIndexPath: indexPath)
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("ArchiveCell", forIndexPath: indexPath) as! ListItemCell
            self.configureArchiveCell(cell, atIndexPath: indexPath)
            return cell
        }
    }

//    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
//        // Return false if you do not want the specified item to be editable.
//        return true
//    }

//    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
//        println("willSelectRowAtIndexPath")
//        return indexPath
//    }

//    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
//        println("didSelectRowAtIndexPath")
//    }


    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
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
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let listItem = self.fetchedResultsController.objectAtIndexPath(indexPath) as! ListItem
        if listItem.active { return 60.0 }
        else { return 44.0 }
    }

    
    func configureArchiveCell(cell: ListItemCell, atIndexPath indexPath: NSIndexPath) {
        let listItem = self.fetchedResultsController.objectAtIndexPath(indexPath) as! ListItem
        cell.nameButton.setTitle(listItem.name, forState: .Normal)
        cell.nameButton.sizeToFit()
        cell.listItem = listItem
        cell.delegate = self
        // TODO: get image info
        
    }

    func configureActiveCell(cell: ActiveListItemCell, atIndexPath indexPath: NSIndexPath) {
        let listItem = self.fetchedResultsController.objectAtIndexPath(indexPath) as! ListItem
        cell.nameButton.setTitle(listItem.name, forState: .Normal)
        cell.listItem = listItem
        cell.delegate = self
        // TODO: get image info
        
    }


    func nameTapped(item: ListItem) {
        toggleItemActivation(item)
    }

    func toggleItemActivation(item: ListItem) {
        if item.active { item.active = false }
        else { item.active = true }
        self.model.save()
        tableView.reloadData()
    }
    
    var selectedItem:ListItem?
    
    func thumbnailTapped(item: ListItem) {
        println("thumbnailTapped: item = \(item.name)")
        selectedItem = item
        performSegueWithIdentifier("showItemDetail", sender: self)

    }
    

    // MARK: - Fetched results controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "ListItem")
        
        // define sorting: first by active (for sectioning) then by creation date (within each section)
        let activeDescriptor = NSSortDescriptor(key: "active", ascending: false) // active then archived
        let dateDescriptor = NSSortDescriptor(key: "creationDate", ascending: false) // first in, last out
        fetchRequest.sortDescriptors = [activeDescriptor, dateDescriptor]
        
        let parentListPredicate = NSPredicate(format: "list == %@", self.list) // only items in the parent list
        let noDeletedListPredicate = NSPredicate(format: "toBeDeleted == %@", false) // don't include toBeDeleted
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
            // TODO: add condition for active vs. archive
//            self.configureCell(tableView.cellForRowAtIndexPath(indexPath!)!, atIndexPath: indexPath!)
            println("updated object in section \(indexPath!.section), row \(indexPath!.row)")
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
    
    
    
    // MARK: - Add-New-Item Mechanism
    
    var addNewItemPanel: UIView?
    var addNewItemButton: UIButton?
    var newItemNameField: UITextField?
    var dismissalPanel: UIView?
    var addNewItemPanelDismisser:UITapGestureRecognizer?
    
    
    func buildAddNewItemUI() {
        dismissalPanel = UIView(frame: CGRectMake(0, 0, view.bounds.width, view.bounds.height))
        dismissalPanel!.backgroundColor = UIColor.blackColor()
        dismissalPanel!.alpha = 0
        dismissalPanel!.hidden = true
        self.view.addSubview(dismissalPanel!)
        
        // create panel
        addNewItemPanel = UIView(frame: CGRectMake(0, -250, view.bounds.width, 54))
        addNewItemPanel!.backgroundColor=UIColor.orangeColor()
        
        // create text field
        newItemNameField = UITextField()
        newItemNameField!.frame = CGRectMake(12, 12, view.bounds.width-86, 30)
        newItemNameField!.backgroundColor = UIColor.whiteColor()
        newItemNameField!.layer.cornerRadius = 6
        newItemNameField!.textInputView.layoutMargins.left = 12.0
        newItemNameField!.placeholder = "Name for new item"
        
        // define padding view within text field
        let paddingView = UIView(frame: CGRectMake(0, 0, 8, newItemNameField!.frame.height))
        newItemNameField!.leftView = paddingView
        newItemNameField!.leftViewMode = UITextFieldViewMode.Always
        
        // create button
        addNewItemButton = (UIButton.buttonWithType(.System) as! UIButton)
        addNewItemButton!.backgroundColor = UIColor.blackColor()
        addNewItemButton!.setTitle("Add", forState: UIControlState.Normal)
        addNewItemButton!.frame = CGRectMake(view.bounds.width-62, 12, 50, 30)
        addNewItemButton!.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        addNewItemButton!.addTarget(self, action: "tapAddNewItemButton:", forControlEvents: UIControlEvents.TouchUpInside)
        
        // add field and button to panel and panel to parent view
        addNewItemPanel!.addSubview(newItemNameField!)
        addNewItemPanel!.addSubview(addNewItemButton!)
        self.view.addSubview(addNewItemPanel!)
        
        // define gesture recognizer for dismissal of panel
        addNewItemPanelDismisser = UITapGestureRecognizer(target: self, action: "dismissAddNewItemPanel")
        
    }
    
    
    func displayAddNewItemPanel() {
        self.dismissalPanel!.hidden = false
        UIView.animateWithDuration(0.4,
            animations: {
                self.addNewItemPanel!.frame.origin.y = 0
                self.dismissalPanel!.alpha = 0.75
            },
            completion: {
                _ in
                self.dismissalPanel!.addGestureRecognizer(self.addNewItemPanelDismisser!)
                self.newItemNameField?.becomeFirstResponder()
                
        })
    }
    
    
    func dismissAddNewItemPanel() {
        self.newItemNameField!.resignFirstResponder()
        UIView.animateWithDuration(0.4,
            animations: {
                self.addNewItemPanel!.frame.origin.y = -54
                self.dismissalPanel!.alpha = 0
            },
            completion: {
                _ in
                self.newItemNameField!.text = ""
                self.dismissalPanel!.hidden = true
                self.dismissalPanel!.removeGestureRecognizer(self.addNewItemPanelDismisser!)
        })
    }


    func tapPlusButton(sender: AnyObject) {
        println("add button tapped")
        displayAddNewItemPanel()
    }


    func tapAddNewItemButton(sender: AnyObject) {
        println("tapAddNewItemButton:")
        let newItemName = newItemNameField!.text
        println("new item name = \(newItemName)")
        model.addItemWithName(newItemName, toList: self.list!)
        tableView.reloadData()
        dismissAddNewItemPanel()
    }
    
    
}

