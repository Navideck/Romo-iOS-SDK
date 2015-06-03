//
//  RMTextSwitchCell.h
//  Romo
//

#import <UIKit/UIKit.h>

@interface RMTextSwitchCell : UITableViewCell

@property (nonatomic, strong) UILabel *mainLabel;
@property (nonatomic, strong, readonly) UISwitch *switchButton;

+ (instancetype)dequeueOrCreateCellForTableView:(UITableView *)tableView;

@end
