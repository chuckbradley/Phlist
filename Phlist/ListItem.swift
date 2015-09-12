//
//  ListItem.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/19/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import CoreData
import Parse

@objc(ListItem)

class ListItem : NSManagedObject {

    @NSManaged var parseID: String?
    @NSManaged var name: String
    @NSManaged var searchText: String
    @NSManaged var active: Bool
    @NSManaged var toBeDeleted: Bool
    @NSManaged var creationDate: NSDate
    @NSManaged var modificationDate: NSDate
    @NSManaged var synchronizationDate: NSDate
    @NSManaged var list: List
    @NSManaged var photo: Photo?
    
    
    // session variable
    var parseObject:PFObject?

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    // init from parse item object
    init(parseItemObject:PFObject, list: List, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("ListItem", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        self.list = list
        parseID = parseItemObject.objectId!
        parseObject = parseItemObject
        name = parseItemObject["name"] as! String
        searchText = self.name.lowercaseString
        active = parseItemObject["active"] as! Bool
        toBeDeleted = false
        creationDate = parseItemObject.createdAt!
        modificationDate = NSDate()
        synchronizationDate = NSDate()

        if let parseFile = parseItemObject["photo"] as? PFFile {
            // create Photo instances for the item
            self.photo = Photo(parsePhotoObject: parseFile, listItem: self, context: context)
            parseFile.getDataInBackgroundWithBlock {
                (imageData: NSData?, error: NSError?) -> Void in
                if error == nil {
                    if let imageData = imageData {
                        let image = UIImage(data:imageData)
                        // TODO: add image to cache using self.photo.filename
                        self.photo!.loaded = true
                    }
                }
            }
        }
    }

    init(name:String, list: List, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("ListItem", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        self.name = name
        self.list = list
        searchText = name.lowercaseString
        active = true
        toBeDeleted = false
        creationDate = NSDate()
        modificationDate = NSDate()
        synchronizationDate = (NSDate.distantPast() as! NSDate)
    }
    
    var activityState: String {
        if self.active { return "Active" }
        return "Archived"
    }

    func updateSynchronizationDate() {
        self.synchronizationDate = NSDate()
    }

    func updateModificationDate() {
        self.modificationDate = NSDate()
    }
}