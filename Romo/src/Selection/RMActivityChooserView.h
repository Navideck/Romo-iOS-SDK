//
//  RMActivityChooserView.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMActivityChooserButton.h"

@interface RMActivityChooserView : UIView

@property (nonatomic, strong, readonly) UIButton *backButton;

@property (nonatomic, strong, readonly) RMActivityChooserButton *missionsButton;

@property (nonatomic, strong, readonly) RMActivityChooserButton *theLabButton;

@property (nonatomic, strong, readonly) RMActivityChooserButton *chaseButton;

@property (nonatomic, strong, readonly) RMActivityChooserButton *lineFollowButton;

@property (nonatomic, strong, readonly) RMActivityChooserButton *RomoControlButton;

@property (nonatomic, strong) UILabel *titleLabel;

@end
