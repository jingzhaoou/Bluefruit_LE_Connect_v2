//
//  UartSettingTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 08/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class UartSettingTableViewCell: UITableViewCell {

    // UI
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var switchControl: UISwitch!
    
    var onSwitchEnabled : ((_ enabled: Bool) -> ())?
    var onSegmentedControlIndexChanged : ((_ selectedIndex: Int) -> ())?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    @IBAction func onSwitchValueChanged(_ sender: UISwitch) {
        onSwitchEnabled?(sender.isOn)
    }

    @IBAction func onSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        onSegmentedControlIndexChanged?(sender.selectedSegmentIndex)
    }
}
