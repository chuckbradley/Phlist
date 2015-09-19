//
//  ListItemCell.swift
//  Phlist
//
//  Created by Chuck Bradley on 8/23/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit

protocol ListItemCellDelegate {
    func nameTapped(item:ListItem)
    func thumbnailTapped(item:ListItem)
}

class ListItemCell: UITableViewCell {

    var listItem:ListItem?
    var delegate:ListItemCellDelegate?

    @IBOutlet weak var nameButton: UIButton!

    @IBAction func nameButtonTapped(sender: AnyObject) {
        self.delegate!.nameTapped(listItem!)
    }

}



