//
//  ListItemCell.swift
//  Phlist
//
//  Created by Chuck Bradley on 8/23/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit

protocol ListItemCellDelegate {
    func listItemCellNameTapped(item:ListItem)
    func listItemCellThumbnailTapped(item:ListItem)
}

class ListItemCell: UITableViewCell {

    var listItem:ListItem?
    var delegate:ListItemCellDelegate?

    @IBOutlet weak var nameButton: UIButton!

    @IBAction func nameButtonTapped(sender: AnyObject) {
        guard let controller = self.delegate else { return }
        controller.listItemCellNameTapped(listItem!)
    }

}



