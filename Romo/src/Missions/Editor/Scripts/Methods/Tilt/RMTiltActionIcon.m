//
//  RMTiltActionIcon
//  Romo
//

#import "RMTiltActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMTiltActionIcon ()

@property (nonatomic, strong) UIImageView *phoneTilt;

@end

@implementation RMTiltActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UIImageView *robot = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"baseTiltBig.png"]];
        robot.size = CGSizeMake(robot.width * 0.28, robot.height * 0.28);
        robot.bottom = self.contentView.height - 2;
        robot.centerX = self.contentView.width / 2;
        [self.contentView addSubview:robot];

        _phoneTilt = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iPhoneTiltBig.png"]];
        self.phoneTilt.size = CGSizeMake(self.phoneTilt.width * 0.3, self.phoneTilt.height * 0.25);
        self.phoneTilt.bottom = self.contentView.height - 6;
        self.phoneTilt.centerX = self.contentView.width / 2;
        self.phoneTilt.layer.anchorPoint = CGPointMake(0.5, 1.0);
        self.phoneTilt.transform = CGAffineTransformMakeRotation((-40 * M_PI)/180.0);
        [self.contentView addSubview:self.phoneTilt];
    }
    return self;
}

- (void)setNoddingYes:(BOOL)noddingYes
{
    if (noddingYes != _noddingYes) {
        _noddingYes = noddingYes;
        
        if (noddingYes) {
            self.phoneTilt.transform = CGAffineTransformIdentity;
        }
    }
}

- (void)startAnimating
{
    if (self.isNoddingYes) {
        [UIView animateWithDuration:0.5 delay:0.75 options:0
                         animations:^{
                             self.phoneTilt.transform = CGAffineTransformMakeRotation((5 * M_PI)/180.0);
                         } completion:^(BOOL finished) {
                             if (finished) {
                                 [UIView animateWithDuration:0.5
                                                  animations:^{
                                                      self.phoneTilt.transform = CGAffineTransformMakeRotation((-15 * M_PI)/180.0);
                                                  } completion:^(BOOL finished) {
                                                      if (finished) {
                                                          [UIView animateWithDuration:0.5
                                                                           animations:^{
                                                                               self.phoneTilt.transform = CGAffineTransformMakeRotation(0);
                                                                           } completion:^(BOOL finished) {
                                                                               if (finished) {
                                                                                   [UIView animateWithDuration:0.5
                                                                                                    animations:^{
                                                                                                        self.phoneTilt.transform = CGAffineTransformMakeRotation((-10 * M_PI)/180.0);
                                                                                                    } completion:^(BOOL finished) {
                                                                                                        if (finished) {
                                                                                                            [self startAnimating];
                                                                                                        }
                                                                                                    }];
                                                                               }
                                                                           }];
                                                      }
                                                  }];
                             }
                         }];
    } else {
        [UIView animateWithDuration:1.75 delay:0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse
                         animations:^{
                             self.phoneTilt.transform = CGAffineTransformMakeRotation((20 * M_PI)/180.0);
                         } completion:nil];
    }
}

- (void)stopAnimating
{
    [self.phoneTilt.layer removeAllAnimations];
}

@end
