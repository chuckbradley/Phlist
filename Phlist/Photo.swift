//
//  Photo.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/19/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import CoreData
import Parse

@objc(Photo)

class Photo : NSManagedObject {
    
    @NSManaged var parseID: String
    @NSManaged var filename: String // local filename
    @NSManaged var loaded: Bool
    @NSManaged var toBeDeleted: Bool
    @NSManaged var creationDate: NSDate
    @NSManaged var synchronizationDate: NSDate
    @NSManaged var item: ListItem
    
    // session variable
//    var parseObject:PFObject?

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(parseItemObject:PFObject, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        parseID = parseItemObject.objectId!
        filename = "\(parseItemObject.objectId!).png"
        toBeDeleted = false

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
    
    
    // MARK: - non-managed properties
    
    var defaultImage = UIImage(named: "placeholder")
    
    var image: UIImage? {
        get {
            if let img = Photo.imageCache.imageWithIdentifier(filename) {
                return img
            } else {
                return nil
            }
        }
        set {
            Photo.imageCache.storeImage(newValue, withIdentifier: filename)
        }
    }
    
    
    
    
    var isDownloading = false
    
    
    // MARK: - Utility
    func retrieveImage(parseFile: PFFile) {
            self.isDownloading = true

            parseFile.getDataInBackgroundWithBlock {
                (imageData: NSData?, error: NSError?) -> Void in
                self.isDownloading = false
                if error == nil {
                    if let imageData = imageData {
                        self.image = UIImage(data:imageData)
                        self.loaded = true
                    }
                } else {
                    println("error getting photo image")
                    self.defaultImage = UIImage(named: "no-photo")
                }
            }

            CoreDataStackManager.sharedInstance().saveContext()
        
        
        
        
//            dispatch_async(GlobalUserInitiatedQueue) {
//                Flickr.taskForImageAtUrl(imgUrl) {
//                    imageData, error in
//                    dispatch_async(GlobalMainQueue) {
//                        self.isDownloading = false
//                        if let data = imageData {
//                            self.image = UIImage(data: data)!
//                        } else if error != nil {
//                            self.defaultImage = UIImage(named: "no-photo")
//                        }
//                        self.downloaded = true
//                        self.pin.photosToDownload--
//                        CoreDataStackManager.sharedInstance().saveContext()
//                    }
//                }
//            }

//        } else {
//            self.defaultImage = UIImage(named: "no-photo")
//        }
    }
    
    
    // image cache
    static let imageCache = ImageCache()

    
    
}