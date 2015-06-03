//
//  RMTextButtonCell.h
//  Romo
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RMTextButtonCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *mainLabel;
@property (nonatomic, strong) IBOutlet UIButton *rightButton;

+ (instancetype)dequeueOrCreateCellForTableView:(UITableView *)tableView;

@end
