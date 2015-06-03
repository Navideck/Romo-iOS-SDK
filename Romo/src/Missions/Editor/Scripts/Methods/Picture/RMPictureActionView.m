//
//  RMPictureActionView.m
//  Romo
//

#import "RMPictureActionView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

@interface RMPictureActionView ()
@property (nonatomic, strong) UIImageView *iPhone;

@property (nonatomic, strong) UIImageView *lensGlow;

@end

@implementation RMPictureActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _iPhone = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iphoneCamera.png"]];
        self.iPhone.centerX = self.contentView.width / 2;
        self.iPhone.bottom = self.contentView.height;
        [self.contentView addSubview:self.iPhone];

        _lensGlow = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iphoneCameraGlow.png"]];
        self.lensGlow.center = CGPointMake(61, 31.5);
        self.lensGlow.alpha = 0.0;
        [self.iPhone addSubview:self.lensGlow];
    }
    return self;
}

- (void)startAnimating
{
    [UIView animateWithDuration:0.1 delay:2.0 options:UIViewAnimationOptionAutoreverse
                     animations:^{
                         self.lensGlow.alpha = 1.0;
                     } completion:^(BOOL finished){
                         self.lensGlow.alpha = 0.0;
                         [UIView animateWithDuration:0.1 delay:0.05 options:UIViewAnimationOptionAutoreverse
                                          animations:^{
                                              self.lensGlow.alpha = 1.0;
                                          } completion:^(BOOL finished){
                                              if (finished) {
                                                  self.lensGlow.alpha = 0.0;
                                                  [self startAnimating];
                                              }
                                          }];
                     }];
}

- (void)stopAnimating
{
    [self.lensGlow.layer removeAllAnimations];
}

@end
