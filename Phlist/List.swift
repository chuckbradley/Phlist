//
//  List.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/19/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import CoreData
import Parse

@objc(List)

class List : NSManagedObject {

    @NSManaged var cloudID: String?
    @NSManaged var title: String
    @NSManaged var toBeDeleted: Bool
    @NSManaged var creationDate: NSDate
    @NSManaged var modificationDate: NSDate
    @NSManaged var synchronizationDate: NSDate?
    @NSManaged var items: [ListItem]
    @NSManaged var user: User

    // session variables
    let model = ModelController.one
    var cloudObject:PFObject?

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    // init from saved parse list object
    init(cloudListObject:PFObject, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("List", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        self.cloudObject = cloudListObject
        cloudID = cloudListObject.objectId!
        title = cloudListObject["title"] as! String
        user = model.user!
        creationDate = cloudListObject.createdAt!
        modificationDate = NSDate()
        toBeDeleted = false
        synchronizationDate = NSDate()
    }
    
    // init without parse list object
    init(title:String, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("List", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.title = title
        user = model.user!
        toBeDeleted = false
        creationDate = NSDate()
        modificationDate = NSDate()
        synchronizationDate = (NSDate.distantPast() )
    }

    func updateSynchronizationDate() {
        self.synchronizationDate = NSDate()
    }
    
    func updateModificationDate() {
        self.modificationDate = NSDate()
    }

}