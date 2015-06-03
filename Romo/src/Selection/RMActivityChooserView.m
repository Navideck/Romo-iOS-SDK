//
//  RMActivityChooserView.m
//  Romo
//

#import "RMActivityChooserView.h"

#import "UIView+Additions.h"
#import "UIButton+RMButtons.h"
#import "UIFont+RMFont.h"
#import "RMSpaceScene.h"

@interface RMActivityChooserView ()

@property (nonatomic, strong) RMSpaceScene *spaceScene;

/** Readwrites */
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIView *navigationBar;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) RMActivityChooserButton *missionsButton;
@property (nonatomic, strong) RMActivityChooserButton *theLabButton;
@property (nonatomic, strong) RMActivityChooserButton *chaseButton;
@property (nonatomic, strong) RMActivityChooserButton *lineFollowButton;
@property (nonatomic, strong) RMActivityChooserButton *RomoControlButton;


@end

@implementation RMActivityChooserView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.spaceScene];
        
        [self addSubview:self.scrollView];
        
        [self.scrollView addSubview:self.missionsButton];
        [self.scrollView addSubview:self.theLabButton];
        [self.scrollView addSubview:self.chaseButton];
        [self.scrollView addSubview:self.lineFollowButton];
        [self.scrollView addSubview:self.RomoControlButton];
        
        [self addSubview:self.navigationBar];
        [self addSubview:self.backButton];
        [self addSubview:self.titleLabel];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    float top = 50.0;
    float height = (self.height - top) / 5.0;
    
    // Make the content size equal to all the content + 1
    // in order to allow the user to see that there is nothing more
    // below the last content
    self.scrollView.contentSize = CGSizeMake(self.width, height * 5.0 + 1.0);
    
    self.missionsButton.frame = CGRectMake(0, 0, self.width, height);
    self.theLabButton.frame = CGRectMake(0, height, self.width, height);
    self.chaseButton.frame = CGRectMake(0, height * 2, self.width, height);
    self.lineFollowButton.frame = CGRectMake(0, height * 3, self.width, height);
    self.RomoControlButton.frame = CGRectMake(0, height * 4, self.width, height);
}

#pragma mark - Public Methods

#pragma mark - Private Methods

- (RMActivityChooserButton *)activityButtonWithTitle:(NSString *)title andIconName:(NSString *)iconName
{
    RMActivityChooserButton *newButton = [[RMActivityChooserButton alloc] initWithFrame:CGRectZero];
    [newButton setTitle:title forState:UIControlStateNormal];
    newButton.iconImageView.image = [UIImage imageNamed:iconName];
    return newButton;
}

#pragma mark - Private Properties

- (UIButton *)missionsButton
{
    if (!_missionsButton) {
        _missionsButton = [self activityButtonWithTitle:NSLocalizedString(@"Missions", @"Missions")
                                            andIconName:@"activitySelector_Mission"];
    }
    return _missionsButton;
}

- (UIButton *)theLabButton
{
    if (!_theLabButton) {
        _theLabButton = [self activityButtonWithTitle:NSLocalizedString(@"Lab-Mission-Title", @"The Lab")
                                          andIconName:@"activitySelector_Lab"];
    }
    return _theLabButton;
}

- (UIButton *)chaseButton
{
    if (!_chaseButton) {
        _chaseButton = [self activityButtonWithTitle:NSLocalizedString(@"Chase-Title", @"Chase")
                                         andIconName:@"activitySelector_Chase"];
    }
    return _chaseButton;
}

- (UIButton *)lineFollowButton
{
    if (!_lineFollowButton) {
        _lineFollowButton = [self activityButtonWithTitle:NSLocalizedString(@"Line-Follow-Title", @"Line Follow")
                                              andIconName:@"activitySelector_LineFollow"];
    }
    return _lineFollowButton;
}

- (UIButton *)RomoControlButton
{
    if (!_RomoControlButton) {
        _RomoControlButton = [self activityButtonWithTitle:NSLocalizedString(@"RomoControl-Alert-Title", @"Romo Control")
                                               andIconName:@"activitySelector_RomoControl"];
    }
    return _RomoControlButton;
}

- (UIButton *)backButton
{
    if (!_backButton) {
        _backButton = [UIButton backButtonWithImage:[UIImage imageNamed:@"backButtonImageCreature.png"]];
        // Because the back button is made to be 64 x 64
        // we need to nudge it up by (64 -50)/2 units to center it
        // within a 50 height navigation bar
        _backButton.top = -7;
    }
    return _backButton;
}

- (RMSpaceScene *)spaceScene
{
    if (!_spaceScene) {
        _spaceScene = [[RMSpaceScene alloc] initWithFrame:self.bounds];
        _spaceScene.userInteractionEnabled = NO;
    }
    return _spaceScene;
}

- (UIView *)navigationBar
{
    if (!_navigationBar) {
        _navigationBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.width, 50)];
        _navigationBar.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"missionsTopBarBackground.png"]];
    }
    return _navigationBar;
}

- (UILabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.width, 50)];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.font = [UIFont mediumFont];
        _titleLabel.textColor = [UIColor whiteColor];
    }
    return _titleLabel;
}

- (UIScrollView *)scrollView
{
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, self.navigationBar.height, self.width, self.height - self.navigationBar.height)];
    }
    
    return _scrollView;
}

@end
