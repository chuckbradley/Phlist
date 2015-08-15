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
    
    class func configParseWithOptions(launchOptions: [NSObject: AnyObject]?) {
        // [Optional] Power your app with Local Datastore. For more info, go to
        // https://parse.com/docs/ios_guide#localdatastore/iOS
        // Parse.enableLocalDatastore()
        
        // Initialize Parse.
        Parse.setApplicationId("cP0yBw10ptmzS5qWM1YoIfMbD349OCDYHWpSRScc", clientKey: "KIrDlqUtZ34Jmkb3EosUdoinAv5TMqPnVkreMdNY")
        
        // [Optional] Track statistics around application opens.
        PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
    }


    // MARK: - instance properties & methods

    // MARK: - General
    
    var context: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }

    func save() {
        CoreDataStackManager.sharedInstance().saveContext()
    }


    
    // MARK: - user
    
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
            var cachedUser = PFUser.currentUser()
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
    
    
    
    
    
    // MARK: - Lists
    

    func syncLists(completionHandler: (success: Bool, error: NSError?) -> Void) {
        var newLists = [PFObject]()
        var dictionary = [String:PFObject]()
        let cdLists = getStoredLists()
        if connectivityStatus == NOT_REACHABLE {
            println("getParseLists error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: "com.freedommind.phlist", code: 100, userInfo: nil)
            completionHandler(success: false, error: error)
        } else {
            getParseLists {
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
                    } else { // both lists have content
                        // build a referenceable dictionary with the returned lists
                        for list in pfLists! {
                            dictionary[list.objectId!] = list
                        }
                        // for all the stored lists...
                        for list in cdLists {
                            // if it has a parseID...
                            if list.parseID != nil {
                                // if there is a pflist with that id, pull it from the dictionary...
                                if let pfList = dictionary.removeValueForKey(list.parseID!) {
                                    // if it has been deleted...
                                    if (pfList["deleted"] as! Bool) || list.toBeDeleted {
                                        // flag pfList as deleted
                                        pfList["deleted"] = true
                                        // remove this user as an editor and delete the list from CD
                                        self.removeUserAsEditorFromObject(pfList)
                                        self.context.deleteObject(list)
                                    }
                                } else {
                                    // list has a parseID (once synced) but there is not a match in the cloud
                                    // delete list
                                    self.context.deleteObject(list)
                                }
                                self.save()
                            } else {
                                // if there is no parseID (list created here and not yet synced)...
                                // create a parseList in the cloud
                                if list.toBeDeleted {
                                    self.context.deleteObject(list)
                                    self.save()
                                } else {
                                    self.createParseListFromList(list)
                                }
                            }
                        }
                        // for all remaining lists
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
    

    // retreive lists from cloud
    func getParseLists(handler: (lists:[PFObject]?, error: NSError?)->Void) -> Void {
        if connectivityStatus == NOT_REACHABLE {
            println("getParseLists error: connectivityStatus == NOT_REACHABLE")
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
    func getStoredLists() -> [List] {
        let fetchRequest = NSFetchRequest(entityName:"List")
        
        var error: NSError?
        
        let fetchedResults = context.executeFetchRequest(fetchRequest, error: &error) as? [List]
        
        if let results = fetchedResults {
            return results
        } else {
            return [List]()
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
                list.synchronizationDate = NSDate()
                self.save()
            }
        }
    }

    
    
    
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
                    println("list \"\(title)\" has been saved with id: \(pfList.objectId!)")
                    // update List object with cloud data
                    list.parseID = pfList.objectId!
                    list.creationDate = pfList.createdAt!
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
                    println("list \"\(title)\" has been saved with id: \(pfList.objectId!)")
                    // update List object with cloud data
                    list.parseID = pfList.objectId!
                    list.creationDate = pfList.createdAt!
                    self.save()
                } else {
                    // TODO: handle saving-error
                    println("Error saving parse object - pfList.saveInBackground")
                }
            }
        }
    }

    
    func removeList(list: List) {
        if let parseID = list.parseID {
            if connectivityStatus == NOT_REACHABLE {
                // flag for later deletion
                list.toBeDeleted = true
                save()
            } else {
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

    // confirm new lists
    func confirmNewLists(lists:[PFObject]) {
        for list in lists {
            if let acceptedBy = list["acceptedBy"] as? [String] {
                if find(acceptedBy, self.user!.email) != nil {
                    let cdList = List(parseListObject: list, context: self.context)
                    cdList.synchronizationDate = NSDate()
                } else {
                    // prompt user with invitation
                    // TODO: display a confirmation modal
                    // if yes, add list
                    let cdList = List(parseListObject: list, context: self.context)
                    cdList.synchronizationDate = NSDate()
                    // } else {
                    //     self.removeUserAsEditorFromObject(list)
                    // }
                }
            }
        }
        self.save()
    }




    // MARK: - Items

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
//                    item.parseObject = pfItem
                    item.creationDate = pfItem.createdAt!
                    item.synchronizationDate = NSDate()
                    self.save()
                } else {
                    // TODO: handle saving-error
                    // There was a problem, check error.description
                    println("Error saving parse object")
                }
            }
        } else {
            pfItem.saveInBackgroundWithBlock {
                success, error in
                if success {
                    println("item \"\(name)\" has been saved to list \(list.title) with id: \(pfItem.objectId!)")
                    item.parseID = pfItem.objectId!
//                    item.parseObject = pfItem
                    item.creationDate = pfItem.createdAt!
                    item.synchronizationDate = NSDate()
                    self.save()
                } else {
                    // TODO: handle saving-error
                    // There was a problem, check error.description
                    println("Error saving parse object")
                }
                
            }
        }
        
    }

    





    // MARK: - Global


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
    
    
    class var lastListsUpdate: NSDate? {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            if let update = defaults.objectForKey("lastListsUpdate") as? NSDate {
                return update
            } else {
                return nil
            }
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setObject(newValue, forKey: "lastListsUpdate")
        }
    }



//    func synchronizeLists() {
//        let storedLists = getStoredLists()
//        let syncDate = self.user!.listsSynchronizedAt!
//        getParseLists {
//            lists, error in
//            if error != nil {
//                // error - synchronization not possible
//                // TODO: handle error
//            } else {
//                if lists!.isEmpty {
//                    // add a parse list for each stored list:
//                    for list in storedLists {
//                        self.createParseListFromList(list)
//                    }
//                } else {
//                    // add a parse list for any stored lists newer than the sync date:
//                    for list in storedLists {
//                        if list.creationDate.compare(syncDate) == NSComparisonResult.OrderedDescending {
//                            self.createParseListFromList(list)
//                        }
//                    }
//                    // iterate through parse lists and store any newer than listsSynchronizedAt
//                    for list in lists! {
//                        let creationDate:NSDate = list.createdAt!
//                        let updateDate:NSDate = list.updatedAt!
//                        let listDeleted = list["deleted"] as! Bool
//
//                        if creationDate.compare(syncDate) == NSComparisonResult.OrderedDescending {
//                            // if parse list was _created_ since last sync:
//                            println("creation date: \(creationDate) is later than sync date: \(syncDate)")
//                            if listDeleted {
//                                // if list has already been deleted, clear user from editors
//                                self.removeUserAsEditorFromObject(list)
//                            } else {
//                                // otherwise create List object
//                                let newList = List(parseListObject: list, context: self.context)
//                                self.save()
//                            }
//                        } else if updateDate.compare(syncDate) == NSComparisonResult.OrderedDescending {
//                            // if parse list was _updated_ since last sync:
//                            for sList in storedLists {
//                                // find matching storedList and update values
//                                if sList.parseID == list.objectId {
//                                    if listDeleted {
//                                        // if the list has been deleted, remove user as editor and delete storedList
//                                        self.removeUserAsEditorFromObject(list)
//                                        self.context.deleteObject(sList)
//                                    } else {
//                                        // apply any other updates
//                                        self.updateList(sList, fromParseList: list)
//                                    }
//                                    self.save()
//                                    break
//                                }
//                            }
//                        } else {
//                            // no changes in cloud since last sync
//                        }
//                    } // end parseLists iteration block
//                }
//
//            } // end no-error block
//        }
//    }

//    func updateList(list:List, fromParseList pfList: PFObject) {
//        list.parseID = pfList.objectId!
//        list.title = pfList["title"] as! String
//        list.creationDate = pfList.createdAt!
//        list.synchronizationDate = NSDate()
//        list.parseObject = pfList
//        // TODO: can or should items be updated here, too?
//    }



    
    
//    class func addList(title:String) {
//        // create PFObject
//        let pfList = PFObject(className: "List")
//        pfList["title"] = title
//        // create List object
//        let list = List(title: title, context: CoreDataStackManager.sharedInstance().managedObjectContext!)
//        CoreDataStackManager.sharedInstance().saveContext()
//        // save PFObject
//        pfList.saveInBackgroundWithBlock {
//            (success: Bool, error: NSError?) -> Void in
//            if (success) {
//                // The object has been saved.
//                println("list \"\(title)\" has been saved with id: \(pfList.objectId!)")
//                // get objectId and assign List.id
//                list.id = pfList.objectId!
//                CoreDataStackManager.sharedInstance().saveContext()
//            } else {
//                // TODO: handle saving error
//                // There was a problem, check error.description
//                println("Error saving parse object")
//            }
//        }
//    }
    
    
    
    
    
    
    


    
}
