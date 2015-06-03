//
//  RMTurnActionIcon.m
//  Romo
//

#import "RMTurnActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMTurnActionIcon ()

@property (nonatomic, strong) UIImageView *robot;

@end

@implementation RMTurnActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _robot = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"romoTurn1.png"]];
        self.robot.contentMode = UIViewContentModeCenter;
        self.robot.animationImages = @[
                                       [UIImage smartImageNamed:@"romoTurn1.png"],
                                       [UIImage smartImageNamed:@"romoTurn3.png"],
                                       [UIImage smartImageNamed:@"romoTurn4.png"],
                                       [UIImage smartImageNamed:@"romoTurn5.png"],
                                       [UIImage smartImageNamed:@"romoTurn6.png"],
                                       [UIImage smartImageNamed:@"romoTurn7.png"],
                                       [UIImage smartImageNamed:@"romoTurn8.png"],
                                       [UIImage smartImageNamed:@"romoTurn9.png"],
                                       [UIImage smartImageNamed:@"romoTurn10.png"],
                                       [UIImage smartImageNamed:@"romoTurn11.png"],
                                       [UIImage smartImageNamed:@"romoTurn13.png"],
                                       [UIImage smartImageNamed:@"romoTurn14.png"],
                                       [UIImage smartImageNamed:@"romoTurn15.png"],
                                       [UIImage smartImageNamed:@"romoTurn17.png"],
                                       [UIImage smartImageNamed:@"romoTurn18.png"],
                                       [UIImage smartImageNamed:@"romoTurn19.png"],
                                       [UIImage smartImageNamed:@"romoTurn20.png"],
                                       [UIImage smartImageNamed:@"romoTurn21.png"],
                                       [UIImage smartImageNamed:@"romoTurn24.png"],
                                       [UIImage smartImageNamed:@"romoTurn26.png"],
                                       [UIImage smartImageNamed:@"romoTurn27.png"],
                                       [UIImage smartImageNamed:@"romoTurn28.png"],
                                       [UIImage smartImageNamed:@"romoTurn29.png"],
                                       [UIImage smartImageNamed:@"romoTurn30.png"],
                                       [UIImage smartImageNamed:@"romoTurn31.png"],
                                       [UIImage smartImageNamed:@"romoTurn34.png"],
                                       [UIImage smartImageNamed:@"romoTurn35.png"],
                                       [UIImage smartImageNamed:@"romoTurn36.png"],
                                       [UIImage smartImageNamed:@"romoTurn37.png"],
                                       [UIImage smartImageNamed:@"romoTurn38.png"],
                                       [UIImage smartImageNamed:@"romoTurn39.png"],
                                       [UIImage smartImageNamed:@"romoTurn40.png"],
                                       [UIImage smartImageNamed:@"romoTurn41.png"],
                                       ];
        self.robot.animationRepeatCount = 0;
        self.robot.frame = CGRectMake(0, 0, 200, 200);
        self.robot.transform = CGAffineTransformMakeScale(0.35, 0.35);
        self.robot.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 3);
        self.robot.animationDuration = self.robot.animationImages.count / 24.0;
        [self.contentView addSubview:self.robot];
    }
    return self;
}

- (void)startAnimating
{
    [self.robot startAnimating];
}

- (void)stopAnimating
{
    [self.robot.layer removeAllAnimations];
    [self.robot stopAnimating];
}

@end
