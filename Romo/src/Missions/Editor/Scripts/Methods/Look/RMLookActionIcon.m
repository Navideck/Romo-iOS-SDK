//
//  RMLookIcon.m
//  Romo
//

#import "RMLookActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMLookActionIcon ()

@property (nonatomic, strong) UIView *leftPupil;
@property (nonatomic, strong) UIView *rightPupil;

@end

@implementation RMLookActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UIImageView *eyes = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iconLookEyes.png"]];
        eyes.frame = self.contentView.bounds;
        eyes.contentMode = UIViewContentModeCenter;
        [self.contentView addSubview:eyes];

        _leftPupil = [[UIView alloc] initWithFrame:CGRectMake(15, 38, 10, 10)];
        self.leftPupil.layer.cornerRadius = self.leftPupil.width / 2;
        self.leftPupil.backgroundColor = [UIColor blackColor];
        [self.contentView addSubview:self.leftPupil];

        _rightPupil = [[UIView alloc] initWithFrame:CGRectMake(51, 38, 10, 10)];
        self.rightPupil.layer.cornerRadius = self.rightPupil.width / 2;
        self.rightPupil.backgroundColor = [UIColor blackColor];
        [self.contentView addSubview:self.rightPupil];
    }
    return self;
}

- (void)startAnimating
{
    [UIView animateWithDuration:0.15 delay:1.0 options:0
                     animations:^{
                         self.leftPupil.origin = CGPointMake(26, 38);
                         self.rightPupil.origin = CGPointMake(62, 38);
                     } completion:^(BOOL finished) {
                         if (finished) {
                             [UIView animateWithDuration:0.15 delay:1.0 options:0
                                              animations:^{
                                                  self.leftPupil.origin = CGPointMake(15, 38);
                                                  self.rightPupil.origin = CGPointMake(51, 38);
                                              } completion:^(BOOL finished) {
                                                  if (finished) {
                                                      [self startAnimating];
                                                  }
                                              }];
                         }
                     }];
}

- (void)stopAnimating
{
    [self.leftPupil.layer removeAllAnimations];
    [self.rightPupil.layer removeAllAnimations];
}

@end
