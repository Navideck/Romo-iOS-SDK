//
//  RMLightOnActionIcon
//  Romo
//

#import "RMLightOnActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMLightOnActionIcon ()

@property (nonatomic, strong) UIImageView *robot;

@end

@implementation RMLightOnActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _robot = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"iconLightOn.png"]];
        self.robot.centerX = self.contentView.width / 2;
        [self.contentView addSubview:self.robot];
    }
    return self;
}

@end
