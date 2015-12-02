//
//  User.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/28/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import Foundation
import CoreData
import Parse

@objc(User)

class User : NSManagedObject {
    
    @NSManaged var cloudID: String?
    @NSManaged var email: String?
    @NSManaged var lists: [List]
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    // init from parse list object
    init(cloudUserObject:PFUser, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("User", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.cloudID = cloudUserObject.objectId!
        self.email = cloudUserObject.email!
    }

    // init with no cloud object
    init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("User", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

}
