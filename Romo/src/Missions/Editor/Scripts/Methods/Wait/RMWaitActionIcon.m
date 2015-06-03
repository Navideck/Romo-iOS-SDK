//
//  RMWaitActionIcon
//  Romo
//

#import "RMWaitActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMWaitActionIcon ()

@end

@implementation RMWaitActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UIImageView *timerImage = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iconWait.png"]];
        timerImage.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 2);
        [self.contentView addSubview:timerImage];
    }
    return self;
}

@end
