//
//  DetailViewController.swift
//  Phlist
//
//  Created by Chuck Bradley on 7/12/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import AVFoundation
import UIKit
import MobileCoreServices

class DetailViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let model = ModelController.one
    let maxLargePhotoSize:CGFloat = 1334.0 // physical pixels for 6 (portrait height), 6 Plus would be 1920.0
    let maxSmallPhotoSize:CGFloat = 750.0 // physical pixels for 6 (portrait width), 6 Plus would be 1080.0

    let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera)
    let isRollAvailable = UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.SavedPhotosAlbum)

    var listItem:ListItem!
    
    var tapViewRecognizer: UITapGestureRecognizer? = nil
    var tapImageRecognizer: UITapGestureRecognizer? = nil

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var changeButton: UIButton!


    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = listItem.name
        textField.text = listItem.name

        setFontName("OpenSans", forView: self.view, andSubViews: true)
        setFontName("Menlo-Regular", forView: textField, andSubViews: false)

        tapImageRecognizer = UITapGestureRecognizer(target: self, action: "tapImage:")
        tapViewRecognizer = UITapGestureRecognizer(target: self, action: "tapAway:")
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        imageView.addGestureRecognizer(tapImageRecognizer!)
        self.view.addGestureRecognizer(tapViewRecognizer!)
    }

    override func viewDidLayoutSubviews() {
        updateImageView()
    }


    // MARK: - actions

    @IBAction func tapChangeButton(sender: AnyObject) {
        textField.resignFirstResponder()

        var text = ""
        if textField.text != nil {
            text = textField.text!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        }

        if text.isEmpty {
            text = listItem.name
        } else if text != listItem.name {
            model.changeNameOfItem(listItem, toName: text)
        }
        textField.text = text
        self.title = text
    }


    func tapImage(recognizer: UITapGestureRecognizer) {
        if textField.isFirstResponder() {
            self.view.endEditing(true)
        } else {
            if isCameraAvailable && isRollAvailable {
                choosePhotoSource()
            } else if isCameraAvailable {
                selectNewPhoto(useCamera: true)
            } else if isRollAvailable {
                selectNewPhoto(useCamera: false)
            } else {
                displayModalWithMessage("No photo access available.", andTitle: nil)
            }
        }
    }

    func tapAway(recognizer: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }


    // MARK: - image picker

    func selectNewPhoto(useCamera useCamera:Bool) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = useCamera ? .Camera : .PhotoLibrary
        // UIImagePickerControllerSourceType.SavedPhotosAlbum
        imagePicker.mediaTypes = [kUTTypeImage as String] // requires import MobileCoreServices
        self.presentViewController(imagePicker, animated: true, completion: nil)
    }

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        self.dismissViewControllerAnimated(true, completion: nil)
        let pickedImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        let image = resizedImageFromPickedImage(pickedImage)
        model.assignNewPhotoImage(image, toItem: listItem)
        updateImageView()
    }

    func image(image: UIImage, didFinishSavingWithError error: NSErrorPointer, contextInfo:UnsafePointer<Void>) {
        if error != nil {
            displayModalWithMessage("Failed to save image.", andTitle: "Save Failed")
        }
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }


    // MARK: - utility
    
    func updateImageView() {
        var size = CGSize(width: 1.0, height: 1.0) // default to square
        if let photo = listItem.photoImage {
            imageView.image = photo
            size = photo.size
        }
        let aspectRect = AVMakeRectWithAspectRatioInsideRect(size, imageView.bounds)
        let xOffset = (imageView.frame.width - aspectRect.width) / 2
        imageView.frame = CGRectMake(imageView.frame.origin.x + xOffset, imageView.frame.origin.y, aspectRect.size.width, aspectRect.size.height)
    }

    func choosePhotoSource() {
        let sourceSelectionModal = UIAlertController(title: nil, message: "Use camera or choose from Library?", preferredStyle: UIAlertControllerStyle.ActionSheet)
        
        sourceSelectionModal.addAction(UIAlertAction(title: "Camera", style: .Default, handler: {
            action in
            self.selectNewPhoto(useCamera: true)
        }))
        
        sourceSelectionModal.addAction(UIAlertAction(title: "Library", style: .Default, handler: {
            action in
            self.selectNewPhoto(useCamera: false)
        }))
        
        sourceSelectionModal.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: {
            action in
            sourceSelectionModal.dismissViewControllerAnimated(true, completion: nil)
        }))
        
        presentViewController(sourceSelectionModal, animated: true, completion: nil)
    }

    func displayModalWithMessage(message: String, andTitle title: String?) {
        let alertController: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil) )
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    

    func sizedImageViewRect() -> CGRect {
        var size = CGSize(width: 1.0, height: 1.0)
        if let image = imageView.image {
            size = image.size
        }
        let aspectRect = AVMakeRectWithAspectRatioInsideRect(size, imageView.bounds)
        let xOffset = (imageView.frame.width - aspectRect.width) / 2
        let rect = CGRectMake(imageView.frame.origin.x + xOffset, imageView.frame.origin.y, aspectRect.size.width, aspectRect.size.height)
        return rect
    }


    func resizedImageFromPickedImage(image: UIImage) -> UIImage {
        let height = image.size.height
        let width = image.size.width

        let smallDimension = (width < height) ? width : height
        let largeDimension = (width > height) ? width : height

        let smallRatio = maxSmallPhotoSize / smallDimension
        let largeRatio = maxLargePhotoSize / largeDimension

        let ratio = (smallRatio < largeRatio) ? smallRatio : largeRatio

        guard ratio < 1 else { return image }

        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let hasAlpha = true // set to true to avoid pink hue
        let scale: CGFloat = 1.0 // dimensions are absolute (to support sharing to various device sizes)

        UIGraphicsBeginImageContextWithOptions(size, hasAlpha, scale)
        image.drawInRect(CGRect(origin: CGPointZero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }


}

