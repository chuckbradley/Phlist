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

    var context: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }

    func save() {
        CoreDataStackManager.sharedInstance().saveContext()
    }


    // setting for app saving to cloud or not
    private var _clouded:Bool?

    var isClouded:Bool {
        get {
            if _clouded == nil {
                let defaults = NSUserDefaults.standardUserDefaults()
                if defaults.boolForKey("cloudedSet") {
                    _clouded = defaults.boolForKey("clouded")
                } else {
                    _clouded = true
                    defaults.setBool(_clouded!, forKey: "clouded")
                    defaults.setBool(true, forKey: "cloudedSet")
                }
            }
            return _clouded!
        }
        set {
            _clouded = newValue
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setBool(newValue, forKey: "clouded")
            defaults.setBool(true, forKey: "cloudedSet")
        }
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


    func userIsValidCloudUser() -> Bool {
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


    func verifyLocalUser() {
        if user != nil {
            if user!.cloudID == nil {
                return
            } else {
                deleteUser()
            }
        }
        user = User(context: self.context)
        save()
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

    func requestPasswordResetForEmailInBackground(email:String, handler: (success: Bool, error: NSError?) -> Void) {
        PFUser.requestPasswordResetForEmailInBackground(email, block: handler)
    }


    func logIn(email: String, password: String, handler: (success: Bool, error: NSError?) -> Void) -> Void {
        PFUser.logInWithUsernameInBackground(email, password: password) {
            (user: PFUser?, error: NSError?) -> Void in
            if user != nil {
                self.user = User(cloudUserObject: user!, context: self.context)
                self.save()
                handler(success: true, error: nil)
            } else {
                handler(success: false, error: error)
            }
        }
    }


    func signUp(email: String, password: String, handler: (success: Bool, error: NSError?) -> Void) -> Void {
        let user = PFUser()
        user.username = email
        user.email = email
        user.password = password
        user.signUpInBackgroundWithBlock {
            (succeeded: Bool, error: NSError?) -> Void in
            if succeeded {
                self.user = User(cloudUserObject: user, context: self.context)
                self.save()
            }
            handler(success: succeeded, error: error)
        }
    }
    






    // MARK: - General cloud object

    
    // remove user's email from corresponding cloud object's editors array
    // and delete cloud object if no editors remain
    func removeUserAsEditorFromCloudObject(cloudObject: PFObject) {
        var changed = false
        let email = self.user!.email!
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


    // add user's email to corresponding cloud object's editors array
    func addUserAsEditorToCloudObject(cloudObject: PFObject, handler: ((success: Bool, error: NSError?) -> Void)?) {
        let email = self.user!.email!
        var changed = false
        
        if let editors = cloudObject["editors"] as? [String] {
            var editorList = editors
            if !editorList.contains(email) {
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
        // create basic List object
        let list = List(title: title, context: context)
        save()

        if isClouded {
            // create PFObject
            let cloudList = PFObject(className: "List")
            cloudList["title"] = title
            cloudList["deleted"] = false
            cloudList["editors"] = [self.user!.email!]
            cloudList["acceptedBy"] = [self.user!.email!]
            
            // save PFObject
            if connectivityStatus == NOT_REACHABLE {
                // wait until later to sync
                cloudList.saveEventually {
                    (success: Bool, error: NSError?) -> Void in
                    if (success) {
                        // update List object with cloud data
                        list.cloudID = cloudList.objectId!
                        list.creationDate = cloudList.createdAt!
                        list.updateModificationDate()
                        list.updateSynchronizationDate()
                        self.save()
                    }
                }
            } else {
                cloudList.saveInBackgroundWithBlock {
                    (success: Bool, error: NSError?) -> Void in
                    if (success) {
                        // update List object with cloud data
                        list.cloudID = cloudList.objectId!
                        list.creationDate = cloudList.createdAt!
                        list.updateModificationDate()
                        list.updateSynchronizationDate()
                        self.save()
                    }
                }
            }
        }
    }

    
    // create list in cloud from List object
    func createCloudListFromList(list: List) {
        let cloudList = PFObject(className: "List")
        cloudList["title"] = list.title
        cloudList["deleted"] = false
        cloudList["editors"] = [self.user!.email!]
        if list.items.count > 0 {
            // add list items to cloud
            var doSave = false
            for item in list.items {
                if item.toBeDeleted {
                    self.context.deleteObject(item)
                    doSave = true
                } else {
                    self.createCloudItemFromListItem(item, andItemIsNew: false)
                }
            }
            if doSave {
                self.save()
            }
        }
        cloudList.saveInBackgroundWithBlock{
            success, error in
            if success {
                list.cloudID = cloudList.objectId!
                list.updateModificationDate()
                list.updateSynchronizationDate()
                self.save()
            }
        }
    }


    // synchronize local lists with user's cloud lists
    func syncLists(completionHandler: (success: Bool, error: NSError?) -> Void) {
        if isClouded {
            if connectivityStatus == NOT_REACHABLE {
                print("syncLists error: connectivityStatus == NOT_REACHABLE")
                let error = NSError(domain: APP_DOMAIN, code: 100, userInfo: nil)
                completionHandler(success: false, error: error)
            } else {
                loadCloudLists {
                    cloudLists, error in
                    var newLists = [PFObject]()
                    var cloudListDict = [String:PFObject]()
                    let storedLists = self.loadStoredLists()
                    if error != nil {
                        // error - synchronization not possible
                        completionHandler(success: false, error: error!)
                    } else {
                        if cloudLists!.isEmpty {
                            for list in storedLists {
                                if list.toBeDeleted {
                                    self.context.deleteObject(list)
                                    self.save()
                                } else {
                                    self.createCloudListFromList(list)
                                }
                            }
                        } else if storedLists.isEmpty {
                            for cloudList in cloudLists! {
                                if (cloudList["deleted"] as! Bool) {
                                    self.removeUserAsEditorFromCloudObject(cloudList)
                                } else {
                                    newLists.append(cloudList)
                                }
                            }
                        } else { // lists exist locally and in cloud
                            // build a referenceable dictionary with the returned lists
                            for list in cloudLists! {
                                cloudListDict[list.objectId!] = list
                            }
                            // for all the stored lists...
                            for list in storedLists {
                                // if it has a cloudID...
                                if let cloudID = list.cloudID {
                                    // if there is a cloudList with that id, pull it from the dictionary...
                                    if let cloudList = cloudListDict.removeValueForKey(cloudID) {
                                        // if it needs to be deleted...
                                        if list.toBeDeleted {
                                            // remove this user as an editor and delete local list
                                            self.removeUserAsEditorFromCloudObject(cloudList)
                                            self.context.deleteObject(list)
                                        } else {
                                            // synchronize list data
                                            let syncDate = list.synchronizationDate!
                                            let modDate = list.modificationDate
                                            let cloudDate = cloudList.updatedAt!
                                            list.cloudObject = cloudList

                                            if modDate.compare(syncDate) == .OrderedDescending || cloudDate.compare(syncDate) == .OrderedDescending {
                                                if modDate.compare(cloudDate) == .OrderedDescending { // local is newer
                                                    self.applyDataOfList(list, toCloudList: cloudList)
                                                } else { // cloud is newer
                                                    self.applyDataOfCloudList(cloudList, toList: list)
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
                                        // create a cloudList in the cloud
                                        self.createCloudListFromList(list)
                                    }
                                }
                            }
                            // add all remaining cloud lists to newLists array
                            for list in cloudListDict.values {
                                newLists.append(list)
                            }
                        }
                        self.importNewCloudLists(newLists)
                        completionHandler(success: true, error: nil)
                    }
                }
            }
        } else {
            completionHandler(success: false, error: nil)
        }
    }
    
    
    // retreive user's lists from cloud
    func loadCloudLists(handler: (lists:[PFObject]?, error: NSError?)->Void) -> Void {
        if connectivityStatus == NOT_REACHABLE {
            print("loadCloudLists error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: APP_DOMAIN, code: 100, userInfo: nil)
            handler(lists: nil, error: error)
        } else {
            let query = PFQuery(className:"List")
            query.whereKey("editors", equalTo: user!.email!)
            query.findObjectsInBackgroundWithBlock {
                (objects: [AnyObject]?, error: NSError?) -> Void in
                if error == nil {
                    // println("retrieved \(objects!.count) lists from cloud")
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
    func assignCloudObjectToList(list: List, handler: (cloudList: PFObject?, error: NSError?) -> Void) {
        if list.cloudObject != nil {
            handler(cloudList: list.cloudObject!, error: nil)
        } else if list.cloudID == nil {
            // list not yet synced - no cloudObject available
            handler(cloudList: nil, error: nil)
        } else {
            if connectivityStatus == NOT_REACHABLE {
                let error = NSError(domain: APP_DOMAIN, code: 100, userInfo: nil)
                handler(cloudList: nil, error: error)
            } else {
                let query = PFQuery(className:"List")
                query.getObjectInBackgroundWithId(list.cloudID!) {
                    cloudList, error in
                    if cloudList != nil {
                        list.cloudObject = cloudList!
                        handler(cloudList: cloudList!, error: nil)
                    } else if error != nil {
                        handler(cloudList: nil, error: error!)
                    }
                }
            }
        }
    }



    func applyDataOfList(list:List, toCloudList cloudList:PFObject) {
        // apply all modifiable properties:
        cloudList["title"] = list.title

        cloudList.saveInBackgroundWithBlock{
            success, error in
            if success {
                list.updateSynchronizationDate()
                self.save()
            }
        }
    }

    func applyDataOfCloudList(cloudList:PFObject, toList list:List) {
        // apply all modifiable properties:
        list.title = cloudList["title"] as! String

        list.updateSynchronizationDate()
        save()
    }


    // invite new user (email) to list
    func inviteAddress(email: String, forList list: List, handler: (success: Bool, error: NSError?) -> Void) {
        if let cloudList = list.cloudObject {
            var editors = cloudList["editors"] as! [String]
            editors.append(email)
            cloudList["editors"] = editors
            cloudList.saveInBackgroundWithBlock (handler)
        }
    }


    // confirm user's acceptance of new lists
    func importNewCloudLists(cloudLists:[PFObject]) {
        let invitationsAvailable = invitations.isEmpty ? true : false
        var cloudListIDs = [String]()
        for cloudList in cloudLists {
            if let acceptedBy = cloudList["acceptedBy"] as? [String] {
                // if already accepted (app is repopulating) no confirmation needed
                if acceptedBy.contains(self.user!.email!) { // if user has already accepted the list
                    _ = List(cloudListObject: cloudList, context: self.context)
                    self.save()
                } else if invitationsAvailable { // if user hasn't yet accepted and invitations haven't already been defined
                    if !cloudListIDs.contains(cloudList.objectId!) { // prevent duplicates
                        invitations.append(cloudList)
                    }
                }
            }
            cloudListIDs.append(cloudList.objectId!)
        }
    }


    func loadUserGroupsForList(list:List, handler: (userArrays: (users:[String], editors:[String]), error: NSError?) -> Void) {
        if let cloudList = list.cloudObject {
            let userArrays = extractUserArraysFromCloudList(cloudList)
            if userArrays.users.isEmpty {
                handler(
                    userArrays: userArrays,
                    error: NSError(
                        domain: APP_DOMAIN,
                        code: 101,
                        userInfo: [NSLocalizedDescriptionKey: "No users found"])
                )
            } else {
                handler(userArrays: userArrays, error: nil)
            }
        } else {
            handler(userArrays: ([], []), error: nil)
        }
    }


    func updateUserGroupsForList(list:List, handler: (userArrays: (users:[String], editors:[String]), error: NSError?) -> Void) {
        updateCloudListForList(list) {
            cloudList, error in
            if let cloudList = list.cloudObject {
                let userArrays = self.extractUserArraysFromCloudList(cloudList)
                if userArrays.users.isEmpty {
                    handler(
                        userArrays: userArrays,
                        error: NSError(
                            domain: APP_DOMAIN,
                            code: 101,
                            userInfo: [NSLocalizedDescriptionKey: "No users found"])
                    )
                } else {
                    handler(userArrays: userArrays, error: nil)
                }
            } else {
                handler(userArrays: ([],[]), error: error)
            }
        }
    }


    // retrieve cloud list for local list
    func updateCloudListForList(list: List, handler: (cloudList: PFObject?, error: NSError?) -> Void) {
        if let cloudList = list.cloudObject { // if the list already has a cloudObject...
            cloudList.fetchInBackgroundWithBlock(handler) // make sure it is up to date
        } else {
            assignCloudObjectToList(list, handler: handler)
        }
    }


    func extractUserArraysFromCloudList(cloudList: PFObject) -> (users:[String], editors:[String]) {
        guard let editors = cloudList["editors"] as? [String] else { return ([], []) }
        guard let users = cloudList["acceptedBy"] as? [String] else { return ([], editors) }
        let editorSet = Set(editors)
        let inviteeSet = editorSet.exclusiveOr(Set(users))
        let invitees = Array(inviteeSet)
        return (users, invitees)
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
            for cloudList in self.invitations {
                _ = List(cloudListObject: cloudList, context: self.context)
                self.save()
                self.addUserAsEditorToCloudObject(cloudList, handler: nil)
            }
            self.invitations = []
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
        createCloudItemFromListItem(item, andItemIsNew: true)
    }


    // save newly created cloud item corresponding to 
    func saveNewCloudItem(cloudItem:PFObject, forItem item:ListItem, andItemIsNew isNew:Bool) {
        if connectivityStatus == NOT_REACHABLE {
            // wait until later to sync
            cloudItem.saveEventually {
                success, error in
                if success {
                    print("item \"\(item.name)\" has been saved to list \(item.list.title) with id: \(cloudItem.objectId!)")
                    item.cloudID = cloudItem.objectId!
                    item.cloudObject = cloudItem
                    if isNew {
                        item.creationDate = cloudItem.createdAt!
                    }
                    item.updateSynchronizationDate()
                    self.save()
                } else {
                    print("Error saving cloud object: saveNewCloudItem: saveEventually")
                }
            }
        } else {
            cloudItem.saveInBackgroundWithBlock {
                success, error in
                if success {
                    print("item \"\(item.name)\" has been saved to list \(item.list.title) with id: \(cloudItem.objectId!)")
                    item.cloudID = cloudItem.objectId!
                    item.cloudObject = cloudItem
                    if isNew {
                        item.creationDate = cloudItem.createdAt!
                    }
                    item.updateSynchronizationDate()
                    self.save()
                } else {
                    print("Error saving cloud object: saveNewCloudItem: saveInBackground")
                }
            }
        }

    }

    // create cloud item from local item
    func createCloudItemFromListItem(item: ListItem, andItemIsNew isNew:Bool) {
        // create PFObject
        let cloudItem = PFObject(className: "ListItem")
        cloudItem["name"] = item.name
        cloudItem["deleted"] = false
        cloudItem["editors"] = [self.user!.email!]
        cloudItem["active"] = item.active
        cloudItem["hasPhoto"] = item.hasPhoto
        cloudItem["photoFilename"] = item.photoFilename
        if item.hasPhoto && item.photoImageData != nil {
            cloudItem["photo"] = PFFile(name: item.photoFilename, data: item.photoImageData!)
        }
        // associate item with parent list
        if let cloudList = item.list.cloudObject {
            cloudItem["list"] = cloudList
            saveNewCloudItem(cloudItem, forItem: item, andItemIsNew: isNew)
        } else {
            assignCloudObjectToList(item.list) {
                cloudList, error in
                if cloudList != nil {
                    cloudItem["list"] = cloudList
                    self.saveNewCloudItem(cloudItem, forItem: item, andItemIsNew: isNew)
                }
            }
        }
    }

    
    // synchronize local items and cloud items for given list
    func syncItemsInList(list: List, completionHandler: (success: Bool, error: NSError?) -> Void) {
        var newCloudItems = [PFObject]()
        var cloudItemDict = [String:PFObject]()
        let storedItems = loadStoredItemsForList(list)
        if connectivityStatus == NOT_REACHABLE {
            print("syncItemsInList error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: APP_DOMAIN, code: 100, userInfo: nil)
            completionHandler(success: false, error: error)
        } else {
            loadCloudItemsForList(list) {
                cloudItems, error in
                if error != nil {
                    // error - synchronization not possible
                    completionHandler(success: false, error: error!)
                } else {
                    if cloudItems!.isEmpty {
                        for item in storedItems {
                            if item.toBeDeleted {
                                self.context.deleteObject(item)
                                self.save()
                            } else {
                                self.createCloudItemFromListItem(item, andItemIsNew: false)
                            }
                        }
                    }
                    else if storedItems.isEmpty {
                        for cloudItem in cloudItems! {
                            if cloudItem["deleted"] as! Bool {
                                self.removeUserAsEditorFromCloudObject(cloudItem)
                            } else {
                                newCloudItems.append(cloudItem)
                            }
                        }
                    }
                    else {
                        for cloudItem in cloudItems! {
                            cloudItemDict[cloudItem.objectId!] = cloudItem
                        }
                        for item in storedItems {
                            if item.cloudID != nil { // if item has ever been synced...
                                if let cloudItem = cloudItemDict.removeValueForKey(item.cloudID!) {
                                    if (cloudItem["deleted"] as! Bool) || item.toBeDeleted {
                                        cloudItem["deleted"] = true
                                        self.removeUserAsEditorFromCloudObject(cloudItem)
                                        self.context.deleteObject(item)
                                        self.save()
                                    } else {
                                        item.cloudObject = cloudItem
                                        let syncDate = item.synchronizationDate
                                        let modDate = item.modificationDate
                                        let cloudDate = cloudItem.updatedAt!
                                        
                                        if modDate.compare(syncDate) == .OrderedDescending || cloudDate.compare(syncDate) == .OrderedDescending {
                                            // apply item data from newer to older source
                                            if modDate.compare(cloudDate) == .OrderedDescending { // local is newer
                                                self.applyDataOfItem(item, toCloudItem: cloudItem)
                                            } else { // cloud is newer
                                                self.applyDataOfCloudItem(cloudItem, toItem: item)
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
                                    self.createCloudItemFromListItem(item, andItemIsNew: false)
                                }
                            }
                        }
                        for cloudItem in cloudItemDict.values {
                            if !(cloudItem["deleted"] as! Bool) {
                                newCloudItems.append(cloudItem)
                            }
                        }
                    }
                    for cloudItem in newCloudItems {
                        let item = ListItem(cloudItemObject: cloudItem, list: list, context: self.context)
                        self.addUserAsEditorToCloudObject(cloudItem) {
                            success, error in
                            if error != nil {
                                print("syncItemsInList: error adding user as editor to new list")
                            }
                        }
                        if item.hasPhoto {
                            self.downloadPhotoFromCloudItem(cloudItem, toItem: item)
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
    func loadCloudItemsForList(list: List, handler: (items:[PFObject]?, error: NSError?) -> Void) {
        if connectivityStatus == NOT_REACHABLE {
            let error = NSError(domain: APP_DOMAIN, code: 100, userInfo: nil)
            handler(items: nil, error: error)
        } else if let cloudList = list.cloudObject {
            self.loadCloudItemsForCloudList(cloudList, filteredForUser: false, handler: handler)
        }
    }


    // retreive cloud items for cloud list
    func loadCloudItemsForCloudList(cloudList: PFObject, filteredForUser: Bool, handler: (items:[PFObject]?, error: NSError?) -> Void) {
        if connectivityStatus == NOT_REACHABLE {
            let error = NSError(domain: APP_DOMAIN, code: 100, userInfo: nil)
            handler(items: nil, error: error)
        } else {
            let query = PFQuery(className:"ListItem")
            query.whereKey("list", equalTo: cloudList)
            if filteredForUser {
                query.whereKey("editors", equalTo: user!.email!)
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
    func loadCloudItemForListItem(item: ListItem, handler: (cloudItem: PFObject?, error: NSError?) -> Void) {
        if let cloudItem = item.cloudObject {
            handler(cloudItem: cloudItem, error: nil)
        } else if connectivityStatus == NOT_REACHABLE {
            print("loadCloudItemForListItem error: connectivityStatus == NOT_REACHABLE")
            let error = NSError(domain: APP_DOMAIN, code: 100, userInfo: nil)
            handler(cloudItem: nil, error: error)
        } else if let id = item.cloudID {
            let query = PFQuery(className:"ListItem")
            query.getObjectInBackgroundWithId(id) {
                cloudItem, error in
                if cloudItem != nil {
                    item.cloudObject = cloudItem!
                    handler(cloudItem: cloudItem!, error: nil)
                } else {
                    handler(cloudItem: nil, error: error)
                }
            }
        } else {
            handler(cloudItem: nil, error: nil)
        }
        
    }


    func changeNameOfItem(item:ListItem, toName name:String) {
        item.name = name
        item.searchText = name.lowercaseString
        item.updateModificationDate()
        save()
        if let cloudItem = item.cloudObject {
            self.applyDataOfItem(item, toCloudItem: cloudItem)
        } else {
            loadCloudItemForListItem(item) {
                cloudItem, error in
                if cloudItem != nil {
                    self.applyDataOfItem(item, toCloudItem: cloudItem!)
                } else if error == nil {
                    self.createCloudItemFromListItem(item, andItemIsNew: false)
                }
            }
        }
    }

    
    func assignNewPhotoImage(image:UIImage, toItem item: ListItem) {
        if item.hasPhoto {
            item.photoImage = nil
        }
        item.modificationDate = NSDate()
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let filename = dateFormatter.stringFromDate(item.modificationDate)
        item.photoFilename = "\(filename).jpg"
        item.hasPhoto = true
        save()
        item.photoImage = image
        if let cloudItem = item.cloudObject {
            self.applyDataOfItem(item, toCloudItem: cloudItem)
        } else {
            loadCloudItemForListItem(item) {
                cloudItem, error in
                if cloudItem != nil {
                    self.applyDataOfItem(item, toCloudItem: cloudItem!)
                } else if error == nil {
                    self.createCloudItemFromListItem(item, andItemIsNew: false)
                }
            }
        }
    }
    
    
    func downloadPhotoFromCloudItem(cloudItem: PFObject, toItem item: ListItem) {
        if let file = cloudItem["photo"] as? PFFile {
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


    func applyDataOfItem(item:ListItem, toCloudItem cloudItem:PFObject) {
        if item.cloudObject == nil {
            item.cloudObject = cloudItem
        }
        // apply all modifiable properties:
        cloudItem["name"] = item.name
        cloudItem["active"] = item.active
        cloudItem["hasPhoto"] = item.hasPhoto
        cloudItem["photoFilename"] = item.photoFilename
        if item.hasPhoto && item.photoImageData != nil {
            cloudItem["photo"] = PFFile(name: item.photoFilename, data: item.photoImageData!)
        }

        cloudItem.saveInBackgroundWithBlock{
            success, error in
            if success {
                item.updateSynchronizationDate()
                self.save()
            }
        }
    }
    

    func applyDataOfCloudItem(cloudItem:PFObject, toItem item:ListItem) {
        if item.cloudObject == nil {
            item.cloudObject = cloudItem
        }
        // apply all modifiable properties:
        item.name = cloudItem["name"] as! String
        item.searchText = item.name.lowercaseString
        item.active = cloudItem["active"] as! Bool
        item.hasPhoto = cloudItem["hasPhoto"] as! Bool

        if item.hasPhoto {
            if let pfPhotoFilename = cloudItem["photoFilename"] as? String {
                if item.photoFilename != pfPhotoFilename {
                    item.photoFilename = pfPhotoFilename
                    if let imageFile = cloudItem["photo"] as? PFFile {
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
        item.photoImage = nil
        if connectivityStatus == NOT_REACHABLE {
            save()
            print("item marked toBeDeleted because no connection")
        } else if let cloudItem = item.cloudObject {
            cloudItem["deleted"] = true
            removeUserAsEditorFromCloudObject(cloudItem)
            context.deleteObject(item)
            save()
            print("item deleted")
        } else {
            loadCloudItemForListItem(item) {
                cloudItem, error in
                if cloudItem != nil {
                    cloudItem!["deleted"] = true
                    self.removeUserAsEditorFromCloudObject(cloudItem!)
                    self.context.deleteObject(item)
                    self.save()
                    print("item deleted after loading cloud item")
                } else {
                    self.save()
                    print("item marked toBeDeleted because cloud item didn't load")
                }
            }
        }
    }


}
