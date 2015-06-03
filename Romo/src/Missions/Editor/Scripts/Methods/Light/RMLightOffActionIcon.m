//
//  RMSayActionIcon.m
//  Romo
//

#import "RMLightOffActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMLightOffActionIcon ()

@property (nonatomic, strong) UIImageView *robot;

@end

@implementation RMLightOffActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _robot = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iconLightOff.png"]];
        self.robot.centerX = self.contentView.width / 2;
        [self.contentView addSubview:self.robot];
    }
    return self;
}

@end
