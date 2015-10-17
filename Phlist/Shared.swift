//
//  Shared.swift
//  Phlist
//
//  Created by Chuck Bradley on 9/30/15.
//  Copyright © 2015 FreedomMind. All rights reserved.
//

import Foundation
import UIKit


let APP_DOMAIN = "com.freedommind.phlist"


func setFontName(fontName:String, forView view: UIView, andSubViews subViews: Bool) {
    if view.isKindOfClass(UILabel) {
        let label = view as! UILabel
        label.font = UIFont(name: fontName, size: label.font.pointSize)
    } else if view.isKindOfClass(UIButton) {
        let button = view as! UIButton
        let label = button.titleLabel!
        label.font = UIFont(name: fontName, size: label.font.pointSize)
    } else if view.isKindOfClass(UITextField) {
        let field = view as! UITextField
        field.font = UIFont(name: fontName, size: field.font!.pointSize)
    } else if subViews {
        for subview in view.subviews {
            setFontName(fontName, forView: subview, andSubViews: true)
        }
    }
}