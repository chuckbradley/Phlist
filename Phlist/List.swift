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

    @NSManaged var parseID: String?
    @NSManaged var title: String
    @NSManaged var toBeDeleted: Bool
    @NSManaged var creationDate: NSDate
    @NSManaged var modificationDate: NSDate
    @NSManaged var synchronizationDate: NSDate?
    @NSManaged var itemsSynchronizedAt: NSDate?
    @NSManaged var items: [ListItem]
    @NSManaged var user: User

    let model = ModelController.one
    var parseObject:PFObject?

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    // init from saved parse list object
    init(parseListObject:PFObject, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("List", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        self.parseObject = parseListObject
        parseID = parseListObject.objectId!
        title = parseListObject["title"] as! String
        user = model.user!
        creationDate = parseListObject.createdAt!
        modificationDate = NSDate()
        toBeDeleted = false

        /* if items are added to parse object
        // if the parse list object has items, generate ListItem instances and add to array
        if let listItems = parseListObject["items"] as? [PFObject] {
            for item in listItems {
                let listItem = ListItem(parseItemObject: item, list: self, context: context)
                self.items.append(listItem)
            }
        }
        self.itemsSynchronizedAt = NSDate()
        */

        self.synchronizationDate = NSDate()
    }
    
    // init without parse list object
    init(title:String, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("List", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.title = title
        user = model.user!
        toBeDeleted = false
        creationDate = NSDate()
        itemsSynchronizedAt = (NSDate.distantPast() as! NSDate)
        synchronizationDate = (NSDate.distantPast() as! NSDate)
    }

    func updateSynchronizationDate() {
        self.synchronizationDate = NSDate()
    }
    
    func updateModificationDate() {
        self.modificationDate = NSDate()
    }

    func updateItemsSynchronizedAt() {
        self.itemsSynchronizedAt = NSDate()
    }

//    func getParseObjectFromArray(pfObjects: [PFObject]) -> PFObject? {
//        if self.parseObject == nil {
//            for object in pfObjects {
//                if object.objectId == self.parseID {
//                    self.parseObject = object
//                    return object
//                }
//            }
//        }
//        return self.parseObject
//    }

//    func addListItems(listItems:[ListItem]) {
//        for item in listItems {
//            // TODO: check for duplicates
//            self.items.append(item)
//        }
//    }

//    func addParseItemObjects(listItems:[PFObject], context: NSManagedObjectContext) {
//        for item in listItems {
//            let listItem = ListItem(parseItemObject: item, list: self, context: context)
//            // TODO: check for duplicates
//            self.items.append(listItem)
//        }
//    }


}