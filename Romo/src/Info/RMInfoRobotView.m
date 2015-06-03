//
//  RMInfoRobotView.m
//  Romo
//

#import "RMInfoRobotView.h"
#import "UIColor+RMColor.h"
#import "UIView+Additions.h"
#import "UIButton+RMButtons.h"
#import "RMSpaceScene.h"

@interface RMInfoRobotView ()

@property (nonatomic, readwrite, strong) UITableView *tableView;
@property (nonatomic, readwrite, strong) UIView *navigationBar;
@property (nonatomic, readwrite, strong) UIButton *dismissButton;
@property (nonatomic, readwrite, strong) UILabel *titleLabel;
@property (nonatomic, readwrite, strong) RMSpaceScene *spaceScene;

@end

@implementation RMInfoRobotView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        _spaceScene = [[RMSpaceScene alloc] initWithFrame:self.bounds];
        self.accessibilityLabel = @"Info View";
        self.isAccessibilityElement = YES;

        [self addSubview:self.spaceScene];
        [self addSubview:self.tableView];
        [self addSubview:self.navigationBar];
        [self.navigationBar addSubview:self.titleLabel];
    }
    
    return self;
}

- (void)layoutSubviews
{
    self.tableView.frame = CGRectMake(0, self.navigationBar.bottom, self.width, self.height - self.navigationBar.bottom);
}

#pragma mark - Subview Getters

- (UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.rowHeight = 52;

        UIImageView *logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"romotiveLogo.png"]];
        logoView.contentMode = UIViewContentModeBottom;
        logoView.height = 32.0 + logoView.image.size.height;
        _tableView.tableFooterView = logoView;
    }
    return _tableView;
}

- (UIView *)navigationBar
{
    if (!_navigationBar) {
        _navigationBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.width, 64)];
        _navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _navigationBar.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"missionsTopBarBackground.png"]];

        self.dismissButton = [UIButton backButtonWithImage:[UIImage imageNamed:@"backButtonImageCreature.png"]];
        
        self.dismissButton.accessibilityLabel = @"back";
        
        self.dismissButton.isAccessibilityElement = YES;
        [_navigationBar addSubview:self.dismissButton];
        
    }
    return _navigationBar;
}

- (UILabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.backgroundColor = [UIColor clearColor];
    }
    return _titleLabel;
}

@end
