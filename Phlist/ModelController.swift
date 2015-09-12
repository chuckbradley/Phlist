//
//  ModelController.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/19/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import Foundation
import Parse
import CoreData


class ModelController {

    // MARK: - class properties & methods
    
//    private struct Constants {
//        static var singleton: ModelController?
//    }
//
//    class var one: ModelController {
//        if Constants.singleton == nil {
//            Constants.singleton = ModelController()
//        }
//        return Constants.singleton!
//    }

    static let one = ModelController()
    static let imageCache = ImageCache()


    let domain = "com.freedommind.phlist"

    class func configParseWithOptions(launchOptions: [NSObject: AnyObject]?) {
        // [Optional] Power your app with Local Datastore. For more info, go to https://parse.com/docs/ios_guide#localdatastore/iOS
        // Parse.enableLocalDatastore()
        
        // Initialize Parse.
        Parse.setApplicationId("cP0yBw10ptmzS5qWM1YoIfMbD349OCDYHWpSRScc", clientKey: "KIrDlqUtZ34Jmkb3EosUdoinAv5TMqPnVkreMdNY")
        
        // [Optional] Track statistics around application opens.
        PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
    }



    // MARK: - Global
    
    var context: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }

    func save() {
        CoreDataStackManager.sharedInstance().saveContext()
    }


    
    // MARK: - User
    
    private var _user:User?
    
    var user:User? {
        get {
            if _user == nil {
                _user = getSingleUser()
            }
            return _user
        }
        set {
            _user = newValue
        }
        
    }
    

    func userIsValid() -> Bool {
        // if there is a saved user:
        if let user = self.user {
            // check for cached Parse user:
            let cachedUser = PFUser.currentUser()
            if cachedUser != nil && user.parseID == cachedUser!.objectId {
//                user.parseUser = cachedUser!
                return true
            } else {
                // otherwise, delete the saved user
                deleteUser()
            }
        }
        return false
    }
    
    
    func getSingleUser() -> User? {
        let fetchRequest = NSFetchRequest(entityName:"User")
        
        var error: NSError?
        
        let fetchedResults = self.context.executeFetchRequest(fetchRequest, error: &error) as? [User]
        
        if let results = fetchedResults {
            if results.count == 0 {
                return nil
            } else {
                // reverse results so oldest is last...
                var users = results.reverse()
                // if more than one, clear out, starting from last...
                while users.count > 1 {
                    let user = users.last
                    context.deleteObject(user!)
                    save()
                    users.removeLast()
                }
                // return remaining user
                return users.last!
            }
        }
        return nil
    }
    
    func deleteUser() {
        if _user != nil {
            context.deleteObject(_user!)
            save()
            _user = nil
        }
    }
    
    func logout(viewController:UIViewController) {
        // delete stored data
        let lists = loadStoredLists()
        for list in lists {
            let items = loadStoredItemsForList(list)
            for item in items {
                context.deleteObject(item)
                // TODO: delete associated photo, if any
            }
            context.deleteObject(list)
        }
        deleteUser()
        // go to login screen
        let controller = viewController.storyboard!.instantiateViewControllerWithIdentifier("Login") as! LoginViewController
        viewController.presentViewController(controller, animated: true, completion: nil)
    }
    
 
    
    // MARK: - General Object
    
    
    // remove user's email from corresponding cloud object's editors array
    // and delete cloud object if no editors remain
    func removeUserAsEditorFromObject(object: PFObject) {
        if let editors = object["editors"] as? [String] {
            var editorList = editors
            for (index, value) in enumerate(editorList) {
                if value == self.user!.email {
                    editorList.removeAtIndex(index)
                    if editorList.isEmpty {
                        // remove object from Parse
                        object.deleteEventually()
                    } else {
                        object["editors"] = editorList
                        object.saveEventually()
                    }
                    break
                }
            }
        }
    }
    
    
    
    // add user's email to corresponding cloud object's editors array
    func addUserAsEditorToObject(object: PFObject, handler: (success: Bool, error: NSError?) -> Void) {
        if let editors = object["editors"] as? [String] {
            var isAdded:Bool = false
            var editorList = editors
            for (index, value) in enumerate(editorList) {
                if value == self.user!.email {
                    isAdded = true
                    break
                }
            }
            if !isAdded {
                editorList.append(self.user!.email)
            }
            object["editors"] = editorList
        } else {
            object["editors"] = [self.user!.email]
        }
        object.saveInBackgroundWithBlock(handler)
    }
    

    
    
    // MARK: - Lists
    
    // create local list and corresponding cloud list with title
    func addListWithTitle(title:String) {
        // create PFObject
        let pfList = PFObject(className: "List")
        pfList["title"] = title
        pfList["deleted"] = false
        pfList["editors"] = [self.user!.email]
        pfList["acceptedBy"] = [self.user!.email]
        
        // create basic List object
        let list = List(title: title, context: context)
        save()
        
        // save PFObject
        if connectivityStatus == NOT_REACHABLE {
            // wait until later to sync
            pfList.saveEventually {
                (success: Bool, error: NSError?) -> Void in
                if (success) {
                    // update List object with cloud data
                    list.parseID = pfList.objectId!
                    list.creationDate = pfList.createdAt!
                    list.updateModificationDate()
                    list.updateSynchronizationDate()
                    self.save()
                } else {
                    // TODO: handle saving-error
                    println("Error saving parse object - pfList.saveEventually")
                }
            }
        } else {
            pfList.saveInBackgroundWithBlock {
                (success: Bool, error: NSError?) -> Void in
                if (success) {
                    // update List object with cloud data
                    list.parseID = pfList.objectId!
                    list.creationDate = pfList.createdAt!
                    list.updateModificationDate()
                    list.updateSynchronizationDate()
                    self.save()
                } else {
                    // TODO: handle saving-error
                    println("Error saving parse object - pfList.saveInBackground")
                }
            }
        }
    }

    
    // create list in cloud from List object
    func createParseListFromList(list: List) {
        let pfList = PFObject(className: "List")
        pfList["title"] = list.title
        pfList["deleted"] = false
        pfList["editors"] = [self.user!.email]
        if list.items.count > 0 {
            // TODO: add list items to cloud?
            println("\(list.title) has \(list.items.count) items")
        }
        pfList.saveInBackgroundWithBlock{
            success, error in
            if success {
                list.parseID = pfList.objectId!
                list.updateModificationDate()
                list.updateSynchronizationDate()
                self.save()
            }
        }
    }


    // synchronize local lists with user's cloud lists
    func syncLists(completionHandler: (success: Bool, error: NSError?) -> Void) {
        if connectivityStatus == NOT_REACHABLE {
            println("syncLists error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: self.domain, code: 100, userInfo: nil)
            completionHandler(success: false, error: error)
        } else {
            var newLists = [PFObject]()
            var dictionary = [String:PFObject]()
            let cdLists = loadStoredLists()
            loadParseLists {
                pfLists, error in
                if error != nil {
                    // error - synchronization not possible
                    // TODO: handle error
                    completionHandler(success: false, error: error!)
                } else {
                    if pfLists!.isEmpty {
                        for list in cdLists {
                            if list.toBeDeleted {
                                self.context.deleteObject(list)
                                self.save()
                            } else {
                                self.createParseListFromList(list)
                            }
                        }
                    } else if cdLists.isEmpty {
                        for list in pfLists! {
                            if (list["deleted"] as! Bool) {
                                self.removeUserAsEditorFromObject(list)
                            } else {
                                newLists.append(list)
                            }
                        }
                    } else { // lists exist locally and in cloud
                        // build a referenceable dictionary with the returned lists
                        for list in pfLists! {
                            dictionary[list.objectId!] = list
                        }
                        // for all the stored lists...
                        for list in cdLists {
                            // if it has a parseID...
                            if let parseID = list.parseID {
                                // if there is a pflist with that id, pull it from the dictionary...
                                if let pfList = dictionary.removeValueForKey(parseID) {
                                    // if it needs to be deleted...
                                    if list.toBeDeleted {
                                        // remove this user as an editor and delete local list
                                        self.removeUserAsEditorFromObject(pfList)
                                        self.context.deleteObject(list)
                                    } else {
                                        // synchronize list data
                                        let syncDate = list.synchronizationDate!
                                        let modDate = list.modificationDate
                                        let cloudDate = pfList.updatedAt!

                                        if modDate.compare(syncDate) == .OrderedDescending || cloudDate.compare(syncDate) == .OrderedDescending {
                                            if modDate.compare(cloudDate) == .OrderedDescending { // local is newer
                                                self.applyDataOfList(list, toParseList: pfList)
                                            } else { // cloud is newer
                                                self.applyDataOfParseList(pfList, toList: list)
                                            }
                                        }
                                    }
                                } else {
                                    // list has a parseID (once synced) but there is not a match in the cloud
                                    // delete local list or recreate cloud list?
                                    self.context.deleteObject(list)
                                }
                                self.save()
                            } else {
                                // if there is no parseID (list created here and not yet synced)...
                                if list.toBeDeleted {
                                    // if to be deleted, remove it from local context
                                    self.context.deleteObject(list)
                                    self.save()
                                } else {
                                    // create a parseList in the cloud
                                    self.createParseListFromList(list)
                                }
                            }
                        }
                        // add all remaining parse lists to newLists
                        for list in dictionary.values {
                            newLists.append(list)
                        }
                    }
                    self.confirmNewLists(newLists)
                    completionHandler(success: true, error: nil)
                }
            }
        }
    }
    
    
    // retreive user's lists from cloud
    func loadParseLists(handler: (lists:[PFObject]?, error: NSError?)->Void) -> Void {
        if connectivityStatus == NOT_REACHABLE {
            println("loadParseLists error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: "com.freedommind.phlist", code: 100, userInfo: nil)
            handler(lists: nil, error: error)
        } else {
            var query = PFQuery(className:"List")
            query.whereKey("editors", equalTo: user!.email)
            query.findObjectsInBackgroundWithBlock {
                (objects: [AnyObject]?, error: NSError?) -> Void in
                if error == nil {
                    // println("retrieved \(objects!.count) lists from Parse")
                    if let objects = objects as? [PFObject] {
                        handler(lists: objects, error: nil)
                    }
                } else {
                    // Log details of the failure
                    let errorString = "Error: \(error!) \(error!.userInfo!)"
                    println(errorString)
                    handler(lists: nil, error: error!)
                }
            }
        }
    }


    // retrieve lists from core data
    func loadStoredLists() -> [List] {
        let fetchRequest = NSFetchRequest(entityName:"List")
        
        var error: NSError?

        // no predicate (get all List objects)
        // specify sort order?
        
        let fetchedResults = context.executeFetchRequest(fetchRequest, error: &error) as? [List]
        
        if let results = fetchedResults {
            return results
        } else {
            return [List]()
        }

    }


    // remove local list and remove user from corresponding cloud list (or flag list to be deleted)
    func removeList(list: List) {
        if let parseID = list.parseID {
            // flag for deletion (now or later)
            list.toBeDeleted = true
            list.updateModificationDate()
            save()
            if connectivityStatus != NOT_REACHABLE {
                PFQuery(className:"List").getObjectInBackgroundWithId(parseID) {
                    object, error in
                    if object != nil {
                        self.removeUserAsEditorFromObject(object!)
                        self.context.deleteObject(list)
                        self.save()
                    }
                }
            }
        } else {
            context.deleteObject(list)
            save()
        }
        
    }

    // confirm user's acceptance of new lists
    func confirmNewLists(lists:[PFObject]) {
        for pfList in lists {
            if let acceptedBy = pfList["acceptedBy"] as? [String] {
                // if already accepted (app is repopulating) no confirmation needed
                if find(acceptedBy, self.user!.email) != nil {
                    let cdList = List(parseListObject: pfList, context: self.context)
                    self.save()
                } else { // if user hasn't already accepted the list, it's an invitation
                    // prompt user with invitation
                    // TODO: display a confirmation modal
                    // if yes, add list
                        self.addUserAsEditorToObject(pfList) {
                            success, error in
                            if success {
                                let cdList = List(parseListObject: pfList, context: self.context)
                                self.save()
                            } else {
                                // TODO: display error message
                                println("confirmNewLists: error adding user as editor")
                            }
                        }
                        // TODO: add user to pfList["acceptedBy"]
                    // } else { // don't create list and remove invitation
                    //     self.removeUserAsEditorFromObject(pfList)
                    // }
                }
            }
        }
    }


    // confirm or obtain the corresponding cloud list for given list
    func assignParseObjectToList(list: List, handler: (success: Bool, parseList: PFObject?, error: NSError?) -> Void) {
        if list.parseObject != nil {
            handler(success: true, parseList: list.parseObject!, error: nil)
        } else if list.parseID != nil {
            if connectivityStatus == NOT_REACHABLE {
                let error = NSError(domain: self.domain, code: 100, userInfo: nil)
                handler(success: false, parseList: nil, error: error)
            } else {
                var query = PFQuery(className:"List")
                query.getObjectInBackgroundWithId(list.parseID!) {
                    pfList, error in
                    if pfList != nil {
                        list.parseObject = pfList!
                        handler(success: true, parseList: pfList!, error: nil)
                    } else if error != nil {
                        handler(success: false, parseList: nil, error: error!)
                    }
                }
            }
        } else {
            // list not yet synced - no parseObject available
            handler(success: false, parseList: nil, error: nil)
        }
    }

    
    func applyDataOfList(list:List, toParseList pfList:PFObject) {
        // apply all modifiable properties:
        pfList["title"] = list.title
        
        pfList.saveInBackgroundWithBlock{
            success, error in
            if success {
                list.updateSynchronizationDate()
                self.save()
            }
        }
    }
    
    func applyDataOfParseList(pfList:PFObject, toList list:List) {
        // apply all modifiable properties:
        list.title = pfList["title"] as! String
        
        list.updateSynchronizationDate()
        save()
    }



    // MARK: - Items

    // create local item and corresponding cloud item for given list
    func addItemWithName(name: String, toList list: List) {
        // create PFObject
        let pfItem = PFObject(className: "ListItem")
        pfItem["name"] = name
        pfItem["deleted"] = false
        pfItem["editors"] = [self.user!.email]
        pfItem["active"] = true
        // associate item with parent list
        if let pfList = list.parseObject {
            pfItem["list"] = pfList
        }
        // create basic ListItem object
        let item = ListItem(name: name, list: list, context: context)
        save()
        // save PFObject
        if connectivityStatus == NOT_REACHABLE {
            // wait until later to sync
            pfItem.saveEventually {
                success, error in
                if success {
                    println("item \"\(name)\" has been saved to list \(list.title) with id: \(pfItem.objectId!)")
                    item.parseID = pfItem.objectId!
                    item.creationDate = pfItem.createdAt!
                    item.updateSynchronizationDate()
                    self.save()
                } else {
                    // TODO: handle saving-error
                    // There was a problem, check error.description
                    println("Error saving parse object: addItemWithName:toList: saveEventually")
                }
            }
        } else {
            pfItem.saveInBackgroundWithBlock {
                success, error in
                if success {
                    println("item \"\(name)\" has been saved to list \(list.title) with id: \(pfItem.objectId!)")
                    item.parseID = pfItem.objectId!
                    item.creationDate = pfItem.createdAt!
                    item.updateSynchronizationDate()
                    self.save()
                } else {
                    // TODO: handle saving-error
                    // There was a problem, check error.description
                    println("Error saving parse object: addItemWithName:toList: saveInBackground")
                }
            }
        }
    }


    // create cloud item from local item
    func createParseListItemFromListItem(item: ListItem) {
        // create PFObject
        let pfItem = PFObject(className: "ListItem")
        pfItem["name"] = item.name
        pfItem["deleted"] = false
        pfItem["editors"] = [self.user!.email]
        pfItem["active"] = item.active
        // associate item with parent list
        if let pfList = item.list.parseObject {
            pfItem["list"] = pfList
        }
        pfItem.saveInBackgroundWithBlock {
            success, error in
            if success {
                item.parseID = pfItem.objectId!
                item.updateSynchronizationDate()
                item.parseObject = pfItem
                self.save()
            }
        }
    }

    
    // synchronize local items and cloud items for given list
    func syncItemsInList(list: List, completionHandler: (success: Bool, error: NSError?) -> Void) {
        var newItems = [PFObject]()
        var dictionary = [String:PFObject]()
        let cdItems = loadStoredItemsForList(list)
        if connectivityStatus == NOT_REACHABLE {
            println("syncItemsInList error: connectivityStatus == NOT_REACHABLE")
            // TODO: learn about NSError
            let error = NSError(domain: self.domain, code: 100, userInfo: nil)
            completionHandler(success: false, error: error)
        } else {
            loadParseItemsForList(list) {
                pfItems, error in
                if error != nil {
                    // error - synchronization not possible
                    // TODO: handle error
                    completionHandler(success: false, error: error!)
                } else {
                    if pfItems!.isEmpty {
                        for item in cdItems {
                            if item.toBeDeleted {
                                self.context.deleteObject(item)
                                self.save()
                            } else {
                                self.createParseListItemFromListItem(item)
                            }
                        }
                    }
                    else if cdItems.isEmpty {
                        for pfItem in pfItems! {
                            if pfItem["deleted"] as! Bool {
                                self.removeUserAsEditorFromObject(pfItem)
                            } else {
                                newItems.append(pfItem)
                            }
                        }
                    }
                    else {
                        for pfItem in pfItems! {
                            dictionary[pfItem.objectId!] = pfItem
                        }
                        for item in cdItems {
                            if item.parseID != nil { // if item has ever been synced...
                                if let pfItem = dictionary.removeValueForKey(item.parseID!) {
                                    if (pfItem["deleted"] as! Bool) || item.toBeDeleted {
                                        pfItem["deleted"] = true
                                        self.removeUserAsEditorFromObject(pfItem)
                                        self.context.deleteObject(item)
                                        self.save()
                                    } else {
                                        item.parseObject = pfItem
                                        let syncDate = item.synchronizationDate
                                        let modDate = item.modificationDate
                                        let cloudDate = pfItem.updatedAt!
                                        
                                        if modDate.compare(syncDate) == .OrderedDescending || cloudDate.compare(syncDate) == .OrderedDescending {
                                            // apply item data from newer to older source
                                            if modDate.compare(cloudDate) == .OrderedDescending { // local is newer
                                                self.applyDataOfItem(item, toParseItem: pfItem)
                                            } else { // cloud is newer
                                                self.applyDataOfParseItem(pfItem, toItem: item)
                                            }
                                        }

                                    }
                                } else { // error case: once-synced local object exists but cloud doesn't
                                    self.context.deleteObject(item)
                                    self.save()
                                }
                            } else { // item has never been synced...
                                if item.toBeDeleted {
                                    self.context.deleteObject(item)
                                    self.save()
                                } else {
                                    self.createParseListItemFromListItem(item)
                                }
                            }
                        }
                        for pfItem in dictionary.values {
                            newItems.append(pfItem)
                        }
                    }
                    for pfItem in newItems {
                        self.addUserAsEditorToObject(pfItem) {
                            success, error in
                            if success {
                                let item = ListItem(parseItemObject: pfItem, list: list, context: self.context)
                                self.save()
                            } else {
                                println("syncItemsInList: error adding user as editor to new list")
                            }
                        }
                    }
                    self.save() // probably not necessary
                    completionHandler(success: true, error: nil)
                }
            }
        }
    }


    // retrieve local items for given list
    func loadStoredItemsForList(list: List) -> [ListItem] {
        let fetchRequest = NSFetchRequest(entityName: "ListItem")
        fetchRequest.predicate = NSPredicate(format: "list == %@", list);
        
        var error: NSError?
        let fetchedResults = context.executeFetchRequest(fetchRequest, error: &error) as? [ListItem]
        
        if let results = fetchedResults {
            return results
        } else {
            return [ListItem]()
        }
        
    }
    

    // retreive cloud items for local list
    func loadParseItemsForList(list: List, handler: (items:[PFObject]?, error: NSError?) -> Void) {
        if connectivityStatus == NOT_REACHABLE {
            println("loadParseLists error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: self.domain, code: 100, userInfo: nil)
            handler(items: nil, error: error)
        } else if let pfList = list.parseObject {
            var query = PFQuery(className:"ListItem")
            query.whereKey("list", equalTo: pfList)
            query.whereKey("editors", equalTo: user!.email)
            query.findObjectsInBackgroundWithBlock {
                (objects: [AnyObject]?, error: NSError?) -> Void in
                if error == nil {
                    // println("retrieved \(objects!.count) lists from Parse")
                    if let objects = objects as? [PFObject] {
                        handler(items: objects, error: nil)
                    }
                } else {
                    // Log details of the failure
                    let errorString = "Error: \(error!) \(error!.userInfo!)"
                    println(errorString)
                    handler(items: nil, error: error!)
                }
            }
        }
    }
    
    
    // retrieve cloud item for local item
    func loadParseItemForListItem(item: ListItem, handler: (pfItem: PFObject?, error: NSError?) -> Void) {
        if let pfItem = item.parseObject {
            handler(pfItem: pfItem, error: nil)
        } else if connectivityStatus == NOT_REACHABLE {
            println("loadParseItemForListItem error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: self.domain, code: 100, userInfo: nil)
            handler(pfItem: nil, error: error)
        } else if let id = item.parseID {
            var query = PFQuery(className:"ListItem")
            query.getObjectInBackgroundWithId(id) {
                pfItem, error in
                if pfItem != nil {
                    item.parseObject = pfItem!
                    handler(pfItem: pfItem!, error: nil)
                } else {
                    handler(pfItem: nil, error: error)
                }
            }
        } else {
            handler(pfItem: nil, error: nil)
        }
        
    }

    func changeNameOfItem(item:ListItem, toName name:String) {
        item.name = name
        item.searchText = name.lowercaseString
        item.updateModificationDate()
        save()
        if let pfItem = item.parseObject {
            self.applyDataOfItem(item, toParseItem: pfItem)
        } else {
            loadParseItemForListItem(item) {
                pfItem, error in
                if pfItem != nil {
                    self.applyDataOfItem(item, toParseItem: pfItem!)
                } else if error == nil {
                    self.createParseListItemFromListItem(item)
                }
            }
        }
    }

    
    func applyDataOfItem(item:ListItem, toParseItem pfItem:PFObject) {
        if item.parseObject == nil {
            item.parseObject = pfItem
        }
        // apply all modifiable properties:
        pfItem["name"] = item.name
        pfItem["active"] = item.active
        // TODO: apply photo
        
        pfItem.saveInBackgroundWithBlock{
            success, error in
            if success {
                item.updateSynchronizationDate()
                self.save()
            }
        }
    }
    
    func applyDataOfParseItem(pfItem:PFObject, toItem item:ListItem) {
        if item.parseObject == nil {
            item.parseObject = pfItem
        }
        // apply all modifiable properties:
        item.name = pfItem["name"] as! String
        item.searchText = item.name.lowercaseString
        item.active = pfItem["active"] as! Bool
        // TODO: apply photo
        
        item.updateModificationDate()
        item.updateSynchronizationDate()
        save()
    }


    func removeItem(item:ListItem) {
        item.toBeDeleted = true
        item.updateModificationDate()
        save()
        if let pfItem = item.parseObject {
            pfItem["deleted"] = true
            removeUserAsEditorFromObject(pfItem)
        } else {
            loadParseItemForListItem(item) {
                pfItem, error in
                if pfItem != nil {
                    pfItem!["deleted"] = true
                    self.removeUserAsEditorFromObject(pfItem!)
                }
            }
        }

    }

    
    
//    class var lastListsUpdate: NSDate? {
//        get {
//            let defaults = NSUserDefaults.standardUserDefaults()
//            if let update = defaults.objectForKey("lastListsUpdate") as? NSDate {
//                return update
//            } else {
//                return nil
//            }
//        }
//        set {
//            let defaults = NSUserDefaults.standardUserDefaults()
//            defaults.setObject(newValue, forKey: "lastListsUpdate")
//        }
//    }



    
    
    
    
    


    
}
