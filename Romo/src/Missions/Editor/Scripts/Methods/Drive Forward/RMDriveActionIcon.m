//
//  RMDriveActionIcon.m
//  Romo
//

#import "RMDriveActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMDriveActionIcon ()

@property (nonatomic, strong) UIImageView *robot;

@end

@implementation RMDriveActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _robot = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"romoDriveForward1.png"]];
        self.robot.animationRepeatCount = 0;
        self.robot.frame = CGRectMake(0, 14, 57.5, 60);
        [self.contentView addSubview:self.robot];
    }
    return self;
}

- (void)startAnimating
{
    self.forward = _forward;
    self.robot.animationDuration = 1.0 / 10.0;
    [self.robot startAnimating];
    
    [UIView animateWithDuration:(_forward ? 2.35 : 3.25) delay:0.0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveLinear
                     animations:^{
                         if (self.forward) {
                             self.robot.left = self.contentView.width + 10.0;
                         } else {
                             self.robot.right = -10.0;
                         }
                     } completion:nil];
}

- (void)stopAnimating
{
    [self.robot.layer removeAllAnimations];
    [self.robot stopAnimating];
}

- (void)setForward:(BOOL)forward
{
    _forward = forward;
    self.robot.left = forward ? -self.robot.width : self.width;

    if (forward) {
        self.robot.animationImages = @[
                                       [UIImage smartImageNamed:@"romoDriveForward1.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward2.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward3.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward4.png"],
                                       ];
    } else {
        self.robot.animationImages = @[
                                       [UIImage smartImageNamed:@"romoDriveForward4.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward3.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward2.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward1.png"],
                                       ];
    }
}

@end
