//
//  RMActivityRobotControllerView.h
//  Romo
//

#import <UIKit/UIKit.h>

@interface RMActivityRobotControllerView : UIView

/**
 Shows the title of the activity
 Only displayed when attentive
 */
@property (nonatomic, strong, readonly) UILabel *titleLabel;

/**
 Shows a space icon for the user to jump to the space screen
 Only displayed when attentive
 */
@property (nonatomic, strong, readonly) UIButton *spaceButton;

/**
 Shows a ? icon for the user to get assistance
 Only displayed when attentive
 */
@property (nonatomic, strong, readonly) UIButton *helpButton;

@property (nonatomic) BOOL showsSpaceButton;
@property (nonatomic) BOOL showsHelpButton;

@property (nonatomic, readonly, getter=isAnimating) BOOL animating;

- (void)layoutForAttentive;
- (void)layoutForInattentive;

@end
