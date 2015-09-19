//
//  ImageDataCache.swift
//  Phlist
//
//  Created by Chuck Bradley on 9/12/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit

class ImageDataCache {
    
    private var dataCache = NSCache()
    
    // MARK: - Retreiving

    // get data for file with given identifier
    func dataFromImageWithIdentifier(identifier: String?) -> NSData? {
        
        // If the identifier is nil, or empty, return nil
        if identifier == nil || identifier! == "" {
            return nil
        }
        
        let path = pathForIdentifier(identifier!)
        
        // First try the memory cache
        if let imageData = dataCache.objectForKey(path) as? NSData {
            return imageData
        }
        
        // Next try the hard drive
        if let data = NSData(contentsOfFile: path) {
            return data
        }
        
        return nil
    }
    

    // get image from file with given identifier
    func imageWithIdentifier(identifier: String?) -> UIImage? {
        if let imageData = dataFromImageWithIdentifier(identifier) {
            return UIImage(data: imageData)
        }
        
        return nil
    }


    // MARK: - Saving

    // store given image with given identifier and optional jpg compression
    func storeImage(image: UIImage?, withIdentifier identifier: String, withCompression jpg: Bool) {
        storeDataForImage(image, withIdentifier: identifier, withCompression: jpg)
    }
    
    // store data for given image with given identifier and optional jpg compression
    func storeDataForImage(image: UIImage?, withIdentifier identifier: String, withCompression jpg: Bool) {
        let path = pathForIdentifier(identifier)
        // If the image is nil, remove images from the cache
        if image == nil {
            dataCache.removeObjectForKey(path)
            NSFileManager.defaultManager().removeItemAtPath(path, error: nil)
            return
        }
        
        let data = jpg ? UIImageJPEGRepresentation(image, 0.6) : UIImagePNGRepresentation(image!)
        dataCache.setObject(data!, forKey: path)
        data!.writeToFile(path, atomically: true)
    }
    
    // store given data with given identifier
    func storeImageData(data: NSData?, withIdentifier identifier: String) {
        let path = pathForIdentifier(identifier)
        
        // If the image is nil, remove images from the cache
        if data == nil {
            dataCache.removeObjectForKey(path)
            NSFileManager.defaultManager().removeItemAtPath(path, error: nil)
            return
        }
        
        // Otherwise, keep the image data in memory and in documents directory
        dataCache.setObject(data!, forKey: path)
        data!.writeToFile(path, atomically: true)
    }
    
    // MARK: - Deletion
    
    // delete all files in document directory
    func deleteAllImages(completionHandler: () -> Void) {
        let fileManager = NSFileManager.defaultManager()
        let documentsDirectoryURL: NSURL = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        if let enumerator = fileManager.enumeratorAtURL(documentsDirectoryURL, includingPropertiesForKeys: nil, options: nil, errorHandler: nil) {
            while let file = enumerator.nextObject() as? String {
                fileManager.removeItemAtURL(documentsDirectoryURL.URLByAppendingPathComponent(file), error: nil)
            }
        }
        completionHandler()
    }
    
    // MARK: - Helper
    
    func pathForIdentifier(identifier: String) -> String {
        let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
        return fullURL.path!
    }


}