//
//  ModelController.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/19/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import Foundation
import CoreData
import Parse


class ModelController {

    // MARK: - class properties & methods

    static let one = ModelController()
    static let imageCache = ImageDataCache()

    class func configParseWithOptions(launchOptions: [NSObject: AnyObject]?) {
        // [Optional] Power your app with Local Datastore. 
        // For more info, go to https://parse.com/docs/ios_guide#localdatastore/iOS
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
            if cachedUser != nil && user.cloudID == cachedUser!.objectId {
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
        
        do {
            let fetchedResults = try self.context.executeFetchRequest(fetchRequest) as? [User]
        
            if let results = fetchedResults {
                if results.count == 0 {
                    return nil
                } else {
                    // reverse results so oldest is last...
                    var users = Array(results.reverse())
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
        } catch {
            print("getSingleUser: error: \(error)")
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
        let controller = viewController.storyboard!.instantiateViewControllerWithIdentifier("Welcome") as! WelcomeViewController
        viewController.presentViewController(controller, animated: true, completion: nil)
    }
    
 
    
    // MARK: - General Object
    
//    
//    // remove user's email from corresponding cloud object's editors array
//    // and delete cloud object if no editors remain
//    func removeUserAsEditorFromCloudItem(pfItem: PFObject) {
//        let email = self.user!.email
//        if let editors = pfItem["editors"] as? [String] {
//            var editorList = editors
//
//            if let edx = find(editorList, email) {
//                editorList.removeAtIndex(edx)
//            }
//
//            if editorList.isEmpty { // if this user was only one, remove item
//                if pfItem["photo"] == nil {
//                    // if no photo, go ahead and remove pfItem from Parse
//                    pfItem.deleteEventually()
//                    println("parseItem deleteEventually")
//                } else { // if pfItem has a photo stored,
//                    // replace photo in cloud with single pixel...
//                    let pixel = UIImage(named: "singlePixel")
//                    let imageData = UIImagePNGRepresentation(pixel!)
//                    pfItem["photo"] = PFFile(name:"pixel.png", data: imageData)
//                    pfItem.saveInBackgroundWithBlock {
//                        success, error in
//                        // after replacing image, delete pfItem from Parse
//                        pfItem.deleteEventually()
//                        println("parseItem with image deleteEventually")
//                    }
//                }
//            } else { // if other editors exist,
//                // just replace editors array with new one without current user
//                pfItem["editors"] = editorList
//                pfItem.saveEventually()
//                println("user removed from parseItem, saveEventually")
//            }
//
//        }
//    }
//    
//
//    // remove user's email from corresponding cloud list's editors array
//    // and delete cloud list if no editors remain
//    func removeUserAsEditorFromCloudList(pfList: PFObject) {
//        let email = self.user!.email
//        if let editors = pfList["editors"] as? [String] {
//            if let users = pfList["acceptedBy"] as? [String] {
//                var editorList = editors
//                var userList = users
//                
//                if let edx = find(editorList, email) {
//                    editorList.removeAtIndex(edx)
//                }
//                
//                if let udx = find(userList, email) {
//                    userList.removeAtIndex(udx)
//                }
//
//                if userList.isEmpty {
//                    pfList.deleteEventually()
//                    println("parseList deleteEventually")
//                } else {
//                    pfList["editors"] = editorList
//                    pfList["acceptedBy"] = userList
//                    pfList.saveEventually()
//                    println("user removed from parseList, saveEventually")
//                }
//                
//            }
//        }
//    }

    
    
    
    
    // remove user's email from corresponding cloud object's editors array
    // and delete cloud object if no editors remain
    func removeUserAsEditorFromCloudObject(cloudObject: PFObject) {
        var changed = false
        let email = self.user!.email
        let isList = cloudObject.parseClassName == "List" ? true : false
        if let editors = cloudObject["editors"] as? [String] {
            var editorList = editors
            var userList:[String]?
            var definingList = [String]()
            
            if let edx = editorList.indexOf(email) {
                editorList.removeAtIndex(edx)
                changed = true
            }

            if isList {
                if let users = cloudObject["acceptedBy"] as? [String] {
                    userList = users
                    if let udx = (userList!).indexOf(email) {
                        userList!.removeAtIndex(udx)
                        changed = true
                    }
                    definingList = userList!
                }
            } else {
                definingList = editorList
            }

            if definingList.isEmpty {
                if isList {
                    // delete child items:
                    loadCloudItemsForCloudList(cloudObject, filteredForUser: false) {
                        cloudItems, error in
                        if cloudItems != nil {
                            PFObject.deleteAllInBackground(cloudItems!)
                        }
                    }
                    cloudObject.deleteEventually()
                    print("\nlast user removed from cloudList, deleteEventually")
                } else if cloudObject["photo"] == nil {
                    cloudObject.deleteEventually()
                    print("\nlast user removed from cloudItem, deleteEventually")
                } else {
                    let pixel = UIImage(named: "singlePixel")
                    let imageData = UIImagePNGRepresentation(pixel!)
                    cloudObject["photo"] = PFFile(name:"pixel.png", data: imageData!)
                    cloudObject.saveInBackgroundWithBlock {
                        success, error in
                        cloudObject.deleteEventually()
                        print("\nlast user removed from cloudListItem with image, deleteEventually")
                    }
                }
            } else if changed {
                cloudObject["editors"] = editorList
                if isList && userList != nil {
                    cloudObject["acceptedBy"] = userList!
                    // remove user from child items
                    loadCloudItemsForCloudList(cloudObject, filteredForUser: true) {
                        cloudItems, error in
                        if cloudItems != nil {
                            for cloudItem in cloudItems! {
                                cloudItem["editors"] = userList!
                            }
                            PFObject.saveAllInBackground(cloudItems!)
                        }
                    }
                }
                cloudObject.saveEventually()
                print("\nuser removed from cloud\(cloudObject.parseClassName), saveEventually")
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
    func addUserAsEditorToCloudObject(cloudObject: PFObject, handler: ((success: Bool, error: NSError?) -> Void)?) {
        let email = self.user!.email
        var changed = false
        
        if let editors = cloudObject["editors"] as? [String] {
            var editorList = editors
            if !editorList.contains(email) {
//            if editorList.indexOf(email) == nil {
                editorList.append(email)
                cloudObject["editors"] = editorList
                changed = true
            }
        } else {
            cloudObject["editors"] = [email]
            changed = true
        }
        
        if cloudObject.parseClassName == "List" {
            if let members = cloudObject["acceptedBy"] as? [String] {
                var memberList = members
                if !memberList.contains(email) {
//                if memberList.indexOf(email) == nil {
                    memberList.append(email)
                    cloudObject["acceptedBy"] = memberList
                    changed = true
                }
            } else {
                cloudObject["acceptedBy"] = [email]
                changed = true
            }
        }

        if changed {
            if let block = handler {
                cloudObject.saveInBackgroundWithBlock(block)
            } else {
                cloudObject.saveInBackground()
            }
        } else if let block = handler {
            block(success: true, error: nil)
        }
    }



    
    
    // MARK: - Lists

    var invitations = [PFObject]()


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
                    list.cloudID = pfList.objectId!
                    list.creationDate = pfList.createdAt!
                    list.updateModificationDate()
                    list.updateSynchronizationDate()
                    self.save()
                } else {
                    // TODO: handle saving-error
                    print("Error saving parse object - pfList.saveEventually")
                }
            }
        } else {
            pfList.saveInBackgroundWithBlock {
                (success: Bool, error: NSError?) -> Void in
                if (success) {
                    // update List object with cloud data
                    list.cloudID = pfList.objectId!
                    list.creationDate = pfList.createdAt!
                    list.updateModificationDate()
                    list.updateSynchronizationDate()
                    self.save()
                } else {
                    // TODO: handle saving-error
                    print("Error saving parse object - pfList.saveInBackground")
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
            print("\(list.title) has \(list.items.count) items")
        }
        pfList.saveInBackgroundWithBlock{
            success, error in
            if success {
                list.cloudID = pfList.objectId!
                list.updateModificationDate()
                list.updateSynchronizationDate()
                self.save()
            }
        }
    }


    // synchronize local lists with user's cloud lists
    func syncLists(completionHandler: (success: Bool, error: NSError?) -> Void) {
        if connectivityStatus == NOT_REACHABLE {
            print("syncLists error: connectivityStatus == NOT_REACHABLE")
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
                                self.removeUserAsEditorFromCloudObject(cloudList)
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
                            // if it has a cloudID...
                            if let cloudID = list.cloudID {
                                // if there is a pflist with that id, pull it from the dictionary...
                                if let pfList = pfListDict.removeValueForKey(cloudID) {
                                    // if it needs to be deleted...
                                    if list.toBeDeleted {
                                        // remove this user as an editor and delete local list
                                        self.removeUserAsEditorFromCloudObject(pfList)
                                        self.context.deleteObject(list)
                                    } else {
                                        // synchronize list data
                                        let syncDate = list.synchronizationDate!
                                        let modDate = list.modificationDate
                                        let cloudDate = pfList.updatedAt!
                                        list.cloudObject = pfList

                                        if modDate.compare(syncDate) == .OrderedDescending || cloudDate.compare(syncDate) == .OrderedDescending {
                                            if modDate.compare(cloudDate) == .OrderedDescending { // local is newer
                                                self.applyDataOfList(list, toParseList: pfList)
                                            } else { // cloud is newer
                                                self.applyDataOfParseList(pfList, toList: list)
                                            }
                                        }
                                    }
                                } else {
                                    // list has a cloudID (once synced) but there is not a match in the cloud
                                    // delete local list or recreate cloud list?
                                    self.context.deleteObject(list)
                                }
                                self.save()
                            } else {
                                // if there is no cloudID (list created here and not yet synced)...
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
                    self.importNewCloudLists(newLists)
                    completionHandler(success: true, error: nil)
                }
            }
        }
    }
    
    
    // retreive user's lists from cloud
    func loadParseLists(handler: (lists:[PFObject]?, error: NSError?)->Void) -> Void {
        if connectivityStatus == NOT_REACHABLE {
            print("loadParseLists error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: "com.freedommind.phlist", code: 100, userInfo: nil)
            handler(lists: nil, error: error)
        } else {
            let query = PFQuery(className:"List")
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
                    let errorString = "Error: \(error!) \(error!.userInfo)"
                    print(errorString)
                    handler(lists: nil, error: error!)
                }
            }
        }
    }


    // retrieve lists from core data
    func loadStoredLists() -> [List] {
        let fetchRequest = NSFetchRequest(entityName:"List")
        
        // no predicate (get all List objects)
        // specify sort order?
        do {
            let fetchedResults = try context.executeFetchRequest(fetchRequest) as? [List]
            
            if let results = fetchedResults {
                return results
            } else {
                return [List]()
            }
        } catch {
            print(error)
            return [List]()
        }
    }

    
    // confirm or obtain the corresponding cloud list for given list
    func assignParseObjectToList(list: List, handler: (parseList: PFObject?, error: NSError?) -> Void) {
        if list.cloudObject != nil {
            handler(parseList: list.cloudObject!, error: nil)
        } else if list.cloudID != nil {
            if connectivityStatus == NOT_REACHABLE {
                let error = NSError(domain: self.domain, code: 100, userInfo: nil)
                handler(parseList: nil, error: error)
            } else {
                let query = PFQuery(className:"List")
                query.getObjectInBackgroundWithId(list.cloudID!) {
                    pfList, error in
                    if pfList != nil {
                        list.cloudObject = pfList!
                        handler(parseList: pfList!, error: nil)
                    } else if error != nil {
                        handler(parseList: nil, error: error!)
                    }
                }
            }
        } else {
            // list not yet synced - no cloudObject available
            handler(parseList: nil, error: nil)
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



    // retrieve cloud list for local list
    func updateParseListForList(list: List, handler: (pfList: PFObject?, error: NSError?) -> Void) {
        if let pfList = list.cloudObject { // if the list already has a cloudObject...
            pfList.fetchInBackgroundWithBlock(handler) // make sure it is up to date
        } else {
            assignParseObjectToList(list, handler: handler)
        }
    }


    // invite new user (email) to list
    func inviteAddress(email: String, forList list: List, handler: (success: Bool, error: NSError?) -> Void) {
        if let pfList = list.cloudObject {
            var editors = pfList["editors"] as! [String]
            editors.append(email)
            pfList["editors"] = editors
            pfList.saveInBackgroundWithBlock (handler)
        }
    }


    // confirm user's acceptance of new lists
    func importNewCloudLists(cloudLists:[PFObject]) {
        for pfList in cloudLists {
            if let acceptedBy = pfList["acceptedBy"] as? [String] {
                // if already accepted (app is repopulating) no confirmation needed
                if acceptedBy.contains(self.user!.email) {
//                if acceptedBy.indexOf(self.user!.email) != nil {
                    _ = List(parseListObject: pfList, context: self.context)
                    self.save()
                } else { // if user hasn't already accepted the list, it's an invitation
                    if !invitations.contains(pfList) {
//                    if invitations.indexOf(pfList) == nil {
                        invitations.append(pfList)
                    }
                }
            }
        }
    }

    // confirm user's acceptance of new lists
    func confirmInvitationsFromController(controller: UIViewController, confirmationHandler: (confirmed:Bool) -> Void) {
        let title = invitations.count > 1 ? "New Lists" : "New List"
        var message = "Would you like to share the list"
        message += invitations.count > 1 ? "s \"" : " \""
        for (var i=0; i < invitations.count; i++) {
            message += invitations[i]["title"] as! String
            if i == invitations.count-1 { message += "\"?" }
            else if invitations.count == 2 { message += "\" and \"" }
            else if i == invitations.count-2 { message += ",\" and \"" }
            else { message += ", \"" }
        }

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        let destroyAction = UIAlertAction(title: "No", style: .Destructive) { (action) in
            for _ in self.invitations {
                let cloudList:PFObject = self.invitations.removeFirst()
                self.removeUserAsEditorFromCloudObject(cloudList)
            }
            confirmationHandler(confirmed: false)
        }
        alertController.addAction(destroyAction)
        
        let joinAction = UIAlertAction(title: "Yes", style: .Default) { (action) in
            for _ in self.invitations {
                let cloudList:PFObject = self.invitations.removeFirst()
                _ = List(parseListObject: cloudList, context: self.context)
                self.save()
                self.addUserAsEditorToCloudObject(cloudList, handler: nil)
            }
            confirmationHandler(confirmed: true)
        }
        alertController.addAction(joinAction)
        
        controller.presentViewController(alertController, animated: true, completion: nil)

    }


    // remove local list and remove user from corresponding cloud list (or flag list to be deleted)
    func removeList(list: List, handler: (() -> Void)?) {
        guard let cloudID = list.cloudID else {
            context.deleteObject(list)
            save()
            if let hdlr = handler { hdlr() }
            return
        }
        // flag for deletion (now or later)
        list.toBeDeleted = true
        list.updateModificationDate()
        save()
        if let object = list.cloudObject {
            self.removeUserAsEditorFromCloudObject(object)
            self.context.deleteObject(list)
            self.save()
            if let hdlr = handler { hdlr() }
        } else if connectivityStatus != NOT_REACHABLE {
            PFQuery(className:"List").getObjectInBackgroundWithId(cloudID) {
                object, error in
                if object != nil {
                    self.removeUserAsEditorFromCloudObject(object!)
                    self.context.deleteObject(list)
                    self.save()
                }
                if let hdlr = handler { hdlr() }
            }
        }

//        if let cloudID = list.cloudID {
//            // flag for deletion (now or later)
//            list.toBeDeleted = true
//            list.updateModificationDate()
//            save()
//            if let object = list.cloudObject {
//                self.removeUserAsEditorFromCloudObject(object)
//                self.context.deleteObject(list)
//                self.save()
//                if let hdlr = handler { hdlr() }
//            } else if connectivityStatus != NOT_REACHABLE {
//                PFQuery(className:"List").getObjectInBackgroundWithId(cloudID) {
//                    object, error in
//                    if object != nil {
//                        self.removeUserAsEditorFromCloudObject(object!)
//                        self.context.deleteObject(list)
//                        self.save()
//                    }
//                    if let hdlr = handler { hdlr() }
//                }
//            }
//        } else {
//            context.deleteObject(list)
//            save()
//            if let hdlr = handler { hdlr() }
//        }

    }



    // confirm user's removal of list
    func confirmRemovalOfList(list: List, fromController controller: UIViewController, confirmationHandler: (confirmed:Bool) -> Void) {
        let title = "Confirm Deletion"
        let message = "Are you sure you want to remove \"\(list.title)\"? You will no longer have access to this list or its items."

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)

        let removeAction = UIAlertAction(title: "Remove", style: .Destructive) {
            action in
            self.removeList(list) {
                confirmationHandler(confirmed: true)
            }
        }
        alertController.addAction(removeAction)

        let cancelAction = UIAlertAction(title: "Cancel", style:  .Cancel) {
            action in
            confirmationHandler(confirmed: false)
        }
        alertController.addAction(cancelAction)

        controller.presentViewController(alertController, animated: true, completion: nil)
        
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
        if let pfList = list.cloudObject {
            pfItem["list"] = pfList
        }

        // save PFObject
        if connectivityStatus == NOT_REACHABLE {
            // wait until later to sync
            pfItem.saveEventually {
                success, error in
                if success {
                    print("item \"\(name)\" has been saved to list \(list.title) with id: \(pfItem.objectId!)")
                    item.cloudID = pfItem.objectId!
                    item.creationDate = pfItem.createdAt!
                    item.updateSynchronizationDate()
                    self.save()
                } else {
                    // TODO: handle saving-error
                    // There was a problem, check error.description
                    print("Error saving parse object: addItemWithName:toList: saveEventually")
                }
            }
        } else {
            pfItem.saveInBackgroundWithBlock {
                success, error in
                if success {
                    print("item \"\(name)\" has been saved to list \(list.title) with id: \(pfItem.objectId!)")
                    item.cloudID = pfItem.objectId!
                    item.creationDate = pfItem.createdAt!
                    item.updateSynchronizationDate()
                    self.save()
                } else {
                    // TODO: handle saving-error
                    // There was a problem, check error.description
                    print("Error saving parse object: addItemWithName:toList: saveInBackground")
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
        if let pfList = item.list.cloudObject {
            pfItem["list"] = pfList
        }
        pfItem.saveInBackgroundWithBlock {
            success, error in
            if success {
                item.cloudID = pfItem.objectId!
                item.updateSynchronizationDate()
                item.cloudObject = pfItem
                self.save()
            }
        }
    }

    
    // synchronize local items and cloud items for given list
    func syncItemsInList(list: List, completionHandler: (success: Bool, error: NSError?) -> Void) {
        var newCloudItems = [PFObject]()
        var pfItemDict = [String:PFObject]()
        let cdItems = loadStoredItemsForList(list)
        if connectivityStatus == NOT_REACHABLE {
            print("syncItemsInList error: connectivityStatus == NOT_REACHABLE")
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
                                self.removeUserAsEditorFromCloudObject(pfItem)
                            } else {
                                newCloudItems.append(pfItem)
                            }
                        }
                    }
                    else {
                        for pfItem in pfItems! {
                            pfItemDict[pfItem.objectId!] = pfItem
                        }
                        for item in cdItems {
                            if item.cloudID != nil { // if item has ever been synced...
                                if let pfItem = pfItemDict.removeValueForKey(item.cloudID!) {
                                    if (pfItem["deleted"] as! Bool) || item.toBeDeleted {
                                        pfItem["deleted"] = true
                                        self.removeUserAsEditorFromCloudObject(pfItem)
                                        self.context.deleteObject(item)
                                        self.save()
                                    } else {
                                        item.cloudObject = pfItem
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
                            if !(pfItem["deleted"] as! Bool) {
                                newCloudItems.append(pfItem)
                            }
                        }
                    }
                    for pfItem in newCloudItems {
                        let item = ListItem(parseItemObject: pfItem, list: list, context: self.context)
//                        self.save()
                        self.addUserAsEditorToCloudObject(pfItem) {
                            success, error in
                            if error != nil {
                                print("syncItemsInList: error adding user as editor to new list")
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
        
        do {
            let fetchedResults = try context.executeFetchRequest(fetchRequest) as? [ListItem]
            
            if let results = fetchedResults {
                return results
            } else {
                return [ListItem]()
            }
        } catch {
            print(error)
            return [ListItem]()
        }
        
    }
    

    // retreive cloud items for local list
    func loadParseItemsForList(list: List, handler: (items:[PFObject]?, error: NSError?) -> Void) {
        if connectivityStatus == NOT_REACHABLE {
            let error = NSError(domain: self.domain, code: 100, userInfo: nil)
            handler(items: nil, error: error)
        } else if let pfList = list.cloudObject {
            self.loadCloudItemsForCloudList(pfList, filteredForUser: false, handler: handler)
        }
    }


    // retreive cloud items for cloud list
    func loadCloudItemsForCloudList(cloudList: PFObject, filteredForUser: Bool, handler: (items:[PFObject]?, error: NSError?) -> Void) {
        if connectivityStatus == NOT_REACHABLE {
            let error = NSError(domain: self.domain, code: 100, userInfo: nil)
            handler(items: nil, error: error)
        } else {
            let query = PFQuery(className:"ListItem")
            query.whereKey("list", equalTo: cloudList)
            if filteredForUser {
                query.whereKey("editors", equalTo: user!.email)
            }
            query.findObjectsInBackgroundWithBlock {
                (objects: [AnyObject]?, error: NSError?) -> Void in
                if error == nil {
                    if let cloudItems = objects as? [PFObject] {
                        handler(items: cloudItems, error: nil)
                    } else {
                        handler(items: [PFObject](), error: nil)
                    }
                } else {
                    // Log details of the failure
                    let errorString = "Error: \(error!) \(error!.userInfo)"
                    print(errorString)
                    handler(items: nil, error: error!)
                }
            }
        }
    }
    
    

    // retrieve cloud item for local item
    func loadParseItemForListItem(item: ListItem, handler: (pfItem: PFObject?, error: NSError?) -> Void) {
        if let pfItem = item.cloudObject {
            handler(pfItem: pfItem, error: nil)
        } else if connectivityStatus == NOT_REACHABLE {
            print("loadParseItemForListItem error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: self.domain, code: 100, userInfo: nil)
            handler(pfItem: nil, error: error)
        } else if let id = item.cloudID {
            let query = PFQuery(className:"ListItem")
            query.getObjectInBackgroundWithId(id) {
                pfItem, error in
                if pfItem != nil {
                    item.cloudObject = pfItem!
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
        if let pfItem = item.cloudObject {
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
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let filename = dateFormatter.stringFromDate(item.modificationDate)
        item.photoFilename = "\(filename).jpg"
        save()
        item.photoImage = nil
        item.photoImage = image
        if let pfItem = item.cloudObject {
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
        if item.cloudObject == nil {
            item.cloudObject = pfItem
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
        if item.cloudObject == nil {
            item.cloudObject = pfItem
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
            print("item marked toBeDeleted because no connection")
        } else if let pfItem = item.cloudObject {
            pfItem["deleted"] = true
            removeUserAsEditorFromCloudObject(pfItem)
            context.deleteObject(item)
            save()
            print("item deleted")
        } else {
            loadParseItemForListItem(item) {
                pfItem, error in
                if pfItem != nil {
                    pfItem!["deleted"] = true
                    self.removeUserAsEditorFromCloudObject(pfItem!)
                    self.context.deleteObject(item)
                    self.save()
                    print("item deleted after loading parseItem")
                } else {
                    self.save()
                    print("item marked toBeDeleted because parseItem didn't load")
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
