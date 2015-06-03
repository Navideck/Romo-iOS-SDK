//
//  RMTextLabelCell.h
//  Romo
//
//  Created on 6/19/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RMTextLabelCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *mainLabel;
@property (nonatomic, strong) IBOutlet UILabel *secondaryLabel;

+ (instancetype)dequeueOrCreateCellForTableView:(UITableView *)tableView;

@end
