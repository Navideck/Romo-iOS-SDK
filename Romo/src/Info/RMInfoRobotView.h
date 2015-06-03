//
//  RMInfoRobotView.h
//  Romo
//

#import <UIKit/UIKit.h>

@class RMSpaceScene;

@interface RMInfoRobotView : UIView

@property (nonatomic, readonly, strong) UITableView *tableView;
@property (nonatomic, readonly, strong) UIView *navigationBar;
@property (nonatomic, readonly, strong) UIButton *dismissButton;
@property (nonatomic, readonly, strong) UILabel *titleLabel;
@property (nonatomic, readonly, strong) RMSpaceScene *spaceScene;

@end
