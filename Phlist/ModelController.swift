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

    static let one = ModelController()
    static let imageCache = ImageDataCache()

    class func configParseWithOptions(launchOptions: [NSObject: AnyObject]?) {
        // [Optional] Power your app with Local Datastore. For more info, go to https://parse.com/docs/ios_guide#localdatastore/iOS
        // Parse.enableLocalDatastore()
        
        // Initialize Parse.
        Parse.setApplicationId("cP0yBw10ptmzS5qWM1YoIfMbD349OCDYHWpSRScc", clientKey: "KIrDlqUtZ34Jmkb3EosUdoinAv5TMqPnVkreMdNY")
        
        // [Optional] Track statistics around application opens.
        PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
    }



    // MARK: - Global

    let domain = "com.freedommind.phlist"

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
//                item.photoImageData = nil // remove photo file
                context.deleteObject(item)
            }
            context.deleteObject(list)
        }
        
        ModelController.imageCache.deleteAllImages {
            // after completion of deleteAllImages...
            self.deleteUser()
        }
        // go to login screen
        let controller = viewController.storyboard!.instantiateViewControllerWithIdentifier("Login") as! LoginViewController
        viewController.presentViewController(controller, animated: true, completion: nil)
    }
    
 
    
    // MARK: - General Object
    
    
    // remove user's email from corresponding cloud object's editors array
    // and delete cloud object if no editors remain
    func removeUserAsEditorFromCloudItem(pfItem: PFObject) {
        if let editors = pfItem["editors"] as? [String] {
            var editorList = editors

            for (index, value) in enumerate(editorList) { // enumerate through array of editors
                if value == self.user!.email { // until current user is found
                    editorList.removeAtIndex(index) // remove current user from array
                    break
                }
            }

            if editorList.isEmpty { // if this user was only one, remove item
                if pfItem["photo"] == nil {
                    // if no photo, go ahead and remove pfItem from Parse
                    pfItem.deleteEventually()
                    println("parseItem deleteEventually")
                } else { // if pfItem has a photo stored,
                    // replace photo in cloud with single pixel...
                    let pixel = UIImage(named: "singlePixel")
                    let imageData = UIImagePNGRepresentation(pixel!)
                    pfItem["photo"] = PFFile(name:"pixel.png", data: imageData)
                    pfItem.saveInBackgroundWithBlock {
                        success, error in
                        // after replacing image, delete pfItem from Parse
                        pfItem.deleteEventually()
                        println("parseItem with image deleteEventually")
                    }
                }
            } else { // if other editors exist,
                // just replace editors array with new one without current user
                pfItem["editors"] = editorList
                pfItem.saveEventually()
                println("user removed from parseItem, saveEventually")
            }
            

        }
    }
    
    // remove user's email from corresponding cloud list's editors array
    // and delete cloud list if no editors remain
    func removeUserAsEditorFromCloudList(pfList: PFObject) {
        if let editors = pfList["editors"] as? [String] {
            if let users = pfList["acceptedBy"] as? [String] {
                var editorList = editors
                var userList = users
                
                for (index, value) in enumerate(editorList) { // enumerate through array of editors
                    if value == self.user!.email { // until current user is found
                        editorList.removeAtIndex(index) // remove current user from array
                        break
                    }
                }
                
                for (index, value) in enumerate(userList) { // enumerate through array of editors
                    if value == self.user!.email { // until current user is found
                        userList.removeAtIndex(index) // remove current user from array
                        break
                    }
                }
                
                if userList.isEmpty { // if this user was only one, remove item
                    if pfList["photo"] == nil {
                        // if no photo, go ahead and remove pfList from Parse
                        pfList.deleteEventually()
                        println("parseList deleteEventually")
                    } else { // if pfList has a photo stored,
                        // replace photo in cloud with single pixel...
                        let pixel = UIImage(named: "singlePixel")
                        let imageData = UIImagePNGRepresentation(pixel!)
                        pfList["photo"] = PFFile(name:"pixel.png", data: imageData)
                        pfList.saveInBackgroundWithBlock {
                            success, error in
                            // after replacing image, delete pfList from Parse
                            pfList.deleteEventually()
                            println("parseList with image deleteEventually")
                        }
                    }
                } else { // if other editors exist,
                    // just replace editors and acceptedBy arrays with new ones without current user
                    pfList["editors"] = editorList
                    pfList["acceptedBy"] = userList
                    pfList.saveEventually()
                    println("user removed from parseList, saveEventually")
                }
                
                
            }
        }
    }
//
//    // remove user's email from corresponding cloud object's editors array
//    // and delete cloud object if no editors remain
//    func removeUserAsEditorFromObject(object: PFObject) {
//        if let editors = object["editors"] as? [String] {
//            var editorList = editors
//            for (index, value) in enumerate(editorList) { // enumerate through array of editors
//                if value == self.user!.email { // until current user is found
//                    editorList.removeAtIndex(index) // remove current user from array
//                    if editorList.isEmpty { // if user was only editor...
//                        if object["photo"] == nil {
//                            // if no photo, go ahead and remove object from Parse
//                            object.deleteEventually()
//                            println("parseItem deleteEventually")
//                        } else { // if object has a photo stored,
//                            // replace photo in cloud with single pixel...
//                            let pixel = UIImage(named: "singlePixel")
//                            let imageData = UIImagePNGRepresentation(pixel!)
//                            object["photo"] = PFFile(name:"pixel.png", data: imageData)
//                            object.saveInBackgroundWithBlock {
//                                success, error in
//                                // after replacing image, delete object from Parse
//                                object.deleteEventually()
//                                println("parseItem with image deleteEventually")
//                            }
//                        }
//                    } else { // if other editors exist,
//                        // just replace editors array with new one without current user
//                        object["editors"] = editorList
//                        object.saveEventually()
//                        println("user removed from parseItem, saveEventually")
//                    }
//                    break
//                }
//            }
//        }
//    }
//    
    
    
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
            var pfListDict = [String:PFObject]()
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
                        for cloudList in pfLists! {
                            if (cloudList["deleted"] as! Bool) {
                                self.removeUserAsEditorFromCloudList(cloudList)
                            } else {
                                newLists.append(cloudList)
                            }
                        }
                    } else { // lists exist locally and in cloud
                        // build a referenceable dictionary with the returned lists
                        for list in pfLists! {
                            pfListDict[list.objectId!] = list
                        }
                        // for all the stored lists...
                        for list in cdLists {
                            // if it has a parseID...
                            if let parseID = list.parseID {
                                // if there is a pflist with that id, pull it from the dictionary...
                                if let pfList = pfListDict.removeValueForKey(parseID) {
                                    // if it needs to be deleted...
                                    if list.toBeDeleted {
                                        // remove this user as an editor and delete local list
                                        self.removeUserAsEditorFromCloudList(pfList)
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
                        for list in pfListDict.values {
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


    // retrieve cloud list for local list
    func loadParseListForList(list: List, handler: (pfList: PFObject?, error: NSError?) -> Void) {
        if let pfList = list.parseObject { // if the list already has a parseObject...
            pfList.fetchInBackgroundWithBlock(handler) // make sure it is up to date
        } else if connectivityStatus == NOT_REACHABLE {
            println("loadParseListForList error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: self.domain, code: 100, userInfo: nil)
            handler(pfList: nil, error: error)
        } else if let id = list.parseID {
            var query = PFQuery(className:"List")
            query.getObjectInBackgroundWithId(id) {
                pfList, error in
                if pfList != nil {
                    list.parseObject = pfList!
                    handler(pfList: pfList, error: nil)
                } else {
                    handler(pfList: nil, error: error)
                }
            }
        } else { // list has never been synced, so no cloud list exists
            handler(pfList: nil, error: nil)
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
                        self.removeUserAsEditorFromCloudList(object!)
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


    // invite new user (email) to list
    func inviteAddress(email: String, forList list: List, handler: (success: Bool, error: NSError?) -> Void) {
        if let pfList = list.parseObject {
            var editors = pfList["editors"] as! [String]
            editors.append(email)
            pfList["editors"] = editors
            pfList.saveInBackgroundWithBlock (handler)
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
        // create basic ListItem object
        let item = ListItem(name: name, list: list, context: context)
        save()

        // create PFObject
        let pfItem = PFObject(className: "ListItem")
        pfItem["name"] = name
        pfItem["deleted"] = false
        pfItem["editors"] = [self.user!.email]
        pfItem["active"] = item.active
        pfItem["hasPhoto"] = item.hasPhoto
        pfItem["photoFilename"] = item.photoFilename
        
        // associate item with parent list
        if let pfList = list.parseObject {
            pfItem["list"] = pfList
        }

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
        pfItem["hasPhoto"] = item.hasPhoto
        pfItem["photoFilename"] = item.photoFilename
        if item.hasPhoto && item.photoImageData != nil {
            pfItem["photo"] = PFFile(name: item.photoFilename, data: item.photoImageData!)
        }
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
        var pfItemDict = [String:PFObject]()
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
                                self.removeUserAsEditorFromCloudItem(pfItem)
                            } else {
                                newItems.append(pfItem)
                            }
                        }
                    }
                    else {
                        for pfItem in pfItems! {
                            pfItemDict[pfItem.objectId!] = pfItem
                        }
                        for item in cdItems {
                            if item.parseID != nil { // if item has ever been synced...
                                if let pfItem = pfItemDict.removeValueForKey(item.parseID!) {
                                    if (pfItem["deleted"] as! Bool) || item.toBeDeleted {
                                        pfItem["deleted"] = true
                                        self.removeUserAsEditorFromCloudItem(pfItem)
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
                        for pfItem in pfItemDict.values {
                            newItems.append(pfItem)
                        }
                    }
                    for pfItem in newItems {
                        let item = ListItem(parseItemObject: pfItem, list: list, context: self.context)
//                        self.save()
                        self.addUserAsEditorToObject(pfItem) {
                            success, error in
                            if error != nil {
                                println("syncItemsInList: error adding user as editor to new list")
                            }
                        }
                        if item.hasPhoto {
                            self.downloadPhotoFromParseListItem(pfItem, toListItem: item)
                        }
                    }
                    self.save()
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

    
    func assignNewPhotoImage(image:UIImage, toItem item: ListItem) {
        item.hasPhoto = true
        item.modificationDate = NSDate()
        var dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let filename = dateFormatter.stringFromDate(item.modificationDate)
        item.photoFilename = "\(filename).jpg"
println("photoFilename = \(item.photoFilename)")
        save()
        item.photoImage = nil
        item.photoImage = image
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
    
//    func downloadPhotoForListItem(item: ListItem) {
//        if let pfItem = item.parseObject {
//            downloadPhotoFromParseListItem(pfItem, toListItem: item)
//        } else {
//            loadParseItemForListItem(item) {
//                pfItem, error in
//                if pfItem != nil {
//                    self.downloadPhotoFromParseListItem(pfItem!, toListItem: item)
//                }
//            }
//        }
//    }
    
    func downloadPhotoFromParseListItem(pfItem: PFObject, toListItem item: ListItem) {
        if let file = pfItem["photo"] as? PFFile {
            file.getDataInBackgroundWithBlock {
                data, error in
                if data != nil {
                    item.photoImageData = data!
                    item.updateModificationDate()
                    item.updateSynchronizationDate()
                    self.save()
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
        pfItem["hasPhoto"] = item.hasPhoto
        pfItem["photoFilename"] = item.photoFilename
        if item.hasPhoto && item.photoImageData != nil {
            pfItem["photo"] = PFFile(name: item.photoFilename, data: item.photoImageData!)
        }

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
        item.hasPhoto = pfItem["hasPhoto"] as! Bool

        if item.hasPhoto {
            if let pfPhotoFilename = pfItem["photoFilename"] as? String {
                if item.photoFilename != pfPhotoFilename {
                    item.photoFilename = pfPhotoFilename
                    if let imageFile = pfItem["photo"] as? PFFile {
                        imageFile.getDataInBackgroundWithBlock {
                            data, error in
                            if data != nil {
                                item.photoImageData = data!
                                item.updateModificationDate()
                                item.updateSynchronizationDate()
                                self.save()
                            }
                        }
                    }
                } else {
                    item.updateModificationDate()
                    item.updateSynchronizationDate()
                    save()
                }
            }
        } else {
            item.updateModificationDate()
            item.updateSynchronizationDate()
            save()
        }
        
    }


    func removeItem(item:ListItem) {
        item.toBeDeleted = true
        item.updateModificationDate()
        if connectivityStatus == NOT_REACHABLE {
            save()
            println("item marked toBeDeleted because no connection")
        } else if let pfItem = item.parseObject {
            pfItem["deleted"] = true
            removeUserAsEditorFromCloudItem(pfItem)
            context.deleteObject(item)
            save()
            println("item deleted")
        } else {
            loadParseItemForListItem(item) {
                pfItem, error in
                if pfItem != nil {
                    pfItem!["deleted"] = true
                    self.removeUserAsEditorFromCloudItem(pfItem!)
                    self.context.deleteObject(item)
                    self.save()
                    println("item deleted after loading parseItem")
                } else {
                    self.save()
                    println("item marked toBeDeleted because parseItem didn't load")
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
