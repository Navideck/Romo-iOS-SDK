//
//  RMFartActionIcon.m
//  Romo
//

#import "RMFartActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMFartActionIcon ()

@property (nonatomic, strong) UIImageView *robot;

@end

@implementation RMFartActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UIImageView *fart = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"romoBackfire.png"]];
        fart.contentMode = UIViewContentModeScaleAspectFit;
        fart.size = CGSizeMake(self.contentView.width * 0.75, self.contentView.height * 0.75);
        fart.center = CGPointMake(self.contentView.width / 2.0 + 4.0, self.contentView.height / 2.0);
        [self.contentView addSubview:fart];
    }
    return self;
}

@end
