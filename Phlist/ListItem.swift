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
    
    // Photo properties
    @NSManaged var photoFilename: String // local filename
    @NSManaged var hasPhoto: Bool
    
    // session variable
    var parseObject:PFObject?
    let model = ModelController.one
    let cache = ModelController.imageCache
    var photoLoaded = false

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

        hasPhoto = parseItemObject["hasPhoto"] as! Bool
        photoFilename = hasPhoto ? parseItemObject["photoFilename"] as! String : ""
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

        hasPhoto = false
        photoFilename = ""
    }

    
    // MARK: - Utility
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


    // MARK: - Photo
    
    var photoImage: UIImage? {
        get {
            if let img = cache.imageWithIdentifier(photoFilename) {
                return img
            } else {
                return nil
            }
        }
        set {
            cache.storeDataForImage(newValue, withIdentifier: photoFilename, withCompression: true)
        }
    }

    var photoImageData: NSData? {
        get {
            if let data = cache.dataFromImageWithIdentifier(photoFilename) {
                return data
            } else {
                return nil
            }
        }
        set {
            cache.storeImageData(newValue, withIdentifier: photoFilename)
        }
    }

}