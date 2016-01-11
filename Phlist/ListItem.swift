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

    @NSManaged var cloudID: String?
    @NSManaged var name: String
    @NSManaged var searchText: String
    @NSManaged var position: Int
    @NSManaged var active: Bool
    @NSManaged var toBeDeleted: Bool
    @NSManaged var creationDate: NSDate
    @NSManaged var modificationDate: NSDate
    @NSManaged var synchronizationDate: NSDate
    @NSManaged var list: List
    
    // Photo properties
    @NSManaged var photoFilename: String // local filename
    @NSManaged var hasPhoto: Bool
    
    // session variables
    var cloudObject:PFObject?
    let model = ModelController.one
    let cache = ModelController.imageCache
    var oldPosition:Int?

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    // init from parse item object
    init(cloudItemObject:PFObject, list: List, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("ListItem", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        self.list = list
        cloudID = cloudItemObject.objectId!
        cloudObject = cloudItemObject
        name = cloudItemObject["name"] as! String
        searchText = self.name.lowercaseString
        active = cloudItemObject["active"] as! Bool
        if let listPosition = cloudItemObject["position"] as? Int {
            position = listPosition
        } else {
            position = list.items.count - 1
        }
        toBeDeleted = false
        creationDate = cloudItemObject.createdAt!
        modificationDate = NSDate()
        synchronizationDate = NSDate()

        hasPhoto = cloudItemObject["hasPhoto"] as! Bool
        photoFilename = hasPhoto ? cloudItemObject["photoFilename"] as! String : ""
    }

    init(name:String, list: List, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("ListItem", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        self.name = name
        self.list = list
        searchText = name.lowercaseString
        active = true
        position = list.items.count
        toBeDeleted = false
        creationDate = NSDate()
        modificationDate = NSDate()
        synchronizationDate = (NSDate.distantPast() )

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