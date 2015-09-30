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


class ListItemsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate, UITextFieldDelegate, ListItemCellDelegate {

    var list:List!
    let model = ModelController.one
    var selectedItem:ListItem?

    let PLACEHOLDER_IMAGE_NAME = "phlist-icon-grey"
    
    @IBOutlet weak var tableView: UITableView!

    var refreshControl:UIRefreshControl!

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        // navigation & toolbar:
        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "tapPlusButton:")
        self.navigationItem.rightBarButtonItem = addButton
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()

        self.title = list.title

        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.addTarget(self, action: "pulledTable:", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControl)

        fetchedResultsController.delegate = self

        // temporary add-item UI
        buildAddNewItemUI()

        setFontName("OpenSans", forView: self.view, andSubViews: true)

        do {
            try fetchedResultsController.performFetch()
        } catch _ {
        }

        model.assignParseObjectToList(list) {
            pfList, error in
            if pfList != nil {
                // syncronize items with cloud
                self.model.syncItemsInList(self.list) {
                    success, error in // are parameters even needed?
                    do {
                        try self.fetchedResultsController.performFetch()
                    } catch _ {
                    }
                    self.tableView.reloadData()
                }
            } else {
                do {
                    // just use locally stored items
                    try self.fetchedResultsController.performFetch()
                } catch _ {
                }
                self.tableView.reloadData()
            }
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        selectedItem = nil
    }


    // MARK: - Actions

    @IBAction func tapRemoveListButton(sender: AnyObject) {
        removeList()
    }

    func removeList() {
        model.confirmRemovalOfList(self.list, fromController: self) {
            confirmed in
            if confirmed {
                self.navigationController?.popViewControllerAnimated(true)
            }
        }
    }

    func pulledTable(sender: AnyObject) {
        refreshList()
    }

    func refreshList() {
        model.syncItemsInList(list) {
            success, error in
            do {
                try self.fetchedResultsController.performFetch()
            } catch _ {
            }
            self.tableView.reloadData()
            self.refreshControl.endRefreshing()
        }
    }
    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showItemDetail" {
            let destination = segue.destinationViewController as! DetailViewController
            guard let item = self.selectedItem else { return }
            destination.listItem = item
        } else if segue.identifier == "showListDetail" {
            let destination = segue.destinationViewController as! ListDetailViewController
            destination.list = self.list
        }

    }


    // MARK: - Table View
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {

        // section.description returns "0" for first and "1" for second
        if section.description == "0" {
            if let firstItem = fetchedResultsController.fetchedObjects?[0] as? ListItem {
                if firstItem.active {
                    return "Active"
                }
            }
        }
        return "Archived"

        // FYI:
        // let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        // sectionInfo.indexTitle returns index of title ("A" for "Active", etc.)
        // sectionInfo.name returns value found by sectionNameKeyPath (activityState)
        // section.value returns an Opaque Value
        // section.description returns string of first sortDescriptor
        // println("section.value = \(section.value) and section.description = \(section.description)")
        // println("section name = \(sectionInfo.name) and indexTitle = \(sectionInfo.indexTitle)")
    }


    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header: UITableViewHeaderFooterView = view as! UITableViewHeaderFooterView
        header.contentView.backgroundColor = UIColor.orangeColor()
        header.textLabel!.textColor = UIColor.whiteColor()
        setFontName("OpenSans", forView: header.textLabel!, andSubViews: false)
        header.contentView.frame.size.height = 38.0
    }


    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] 
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
            print("tableView:commitEditingStyle:forRowAtIndexPath[\(indexPath.row)]")
            let item = self.fetchedResultsController.objectAtIndexPath(indexPath) as! ListItem
            model.removeItem(item)
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
        setFontName("OpenSans", forView: cell.nameButton, andSubViews: false)
        cell.nameButton.sizeToFit()
        cell.listItem = listItem
        cell.delegate = self
    }


    func configureActiveCell(cell: ActiveListItemCell, atIndexPath indexPath: NSIndexPath) {
        let listItem = self.fetchedResultsController.objectAtIndexPath(indexPath) as! ListItem
        cell.nameButton.setTitle(listItem.name, forState: .Normal)
        setFontName("OpenSans", forView: cell.nameButton, andSubViews: false)
        cell.listItem = listItem
        if let photo = listItem.photoImage {
            cell.thumbnailButton.setBackgroundImage(photo, forState: .Normal)
        } else {
            cell.thumbnailButton.setBackgroundImage(UIImage(named: PLACEHOLDER_IMAGE_NAME), forState: .Normal)
        }
        cell.delegate = self
    }

    // MARK: - Table Cell Delegate Actions

    func nameTapped(item: ListItem) {
        toggleItemActivation(item)
    }

    func toggleItemActivation(item: ListItem) {
        item.active = !item.active
        item.updateModificationDate()
        self.model.save()
        if let pfItem = item.cloudObject {
            pfItem["active"] = item.active
            pfItem.saveInBackgroundWithBlock{
                success, error in
                if success {
                    item.updateSynchronizationDate()
                    self.model.save()
                }
            }
        }
        tableView.reloadData()
    }
    
    func thumbnailTapped(item: ListItem) {
        selectedItem = item
        model.loadParseItemForListItem(item) {
            pfItem, error in
            if error != nil {
                print("thumbnailTapped error = \(error!.description)")
            } else {
                self.performSegueWithIdentifier("showItemDetail", sender: self)
            }
        }
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
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [parentListPredicate, noDeletedListPredicate])
        
        fetchRequest.predicate = compoundPredicate
        
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
            self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
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
    
    
    
    // MARK: - UI
    
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
        newItemNameField!.returnKeyType = .Done
        newItemNameField!.delegate = self
        
        // create button
        addNewItemButton = UIButton(type: .System)
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
        displayAddNewItemPanel()
    }


    func tapAddNewItemButton(sender: AnyObject) {
        addNewItem()
    }
    
    func addNewItem() {
        var newItemName = ""
        if newItemNameField!.text != nil {
            newItemName = newItemNameField!.text!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        }
        if !newItemName.isEmpty {
            model.addItemWithName(newItemName, toList: list)
            tableView.reloadData()
        }
        dismissAddNewItemPanel()
    }


    func textFieldShouldReturn(textField: UITextField) -> Bool {
        addNewItem()
        return true
    }

}

