//
//  ActiveListItemCell.swift
//  Phlist
//
//  Created by Chuck Bradley on 8/16/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import UIKit

class ActiveListItemCell: ListItemCell {

    @IBOutlet weak var thumbnailButton: UIButton!
    
    @IBAction func thumbnailButtonTapped(sender: AnyObject) {
        guard let controller = self.delegate else { return }
        controller.thumbnailTapped(self.listItem!)
    }
    
}
