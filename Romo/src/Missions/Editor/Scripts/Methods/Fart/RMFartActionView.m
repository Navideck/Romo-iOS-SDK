//
//  RMFartActionView.m
//  Romo
//

#import "RMFartActionView.h"
#import "UIView+Additions.h"

@interface RMFartActionView ()

@property (nonatomic, strong) UIImageView *robot;

@end

@implementation RMFartActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UIImageView *fart = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"romoBackfire.png"]];
        fart.contentMode = UIViewContentModeScaleAspectFit;
        fart.center = CGPointMake(self.contentView.width / 2.0 + 8.0, self.contentView.height / 2.0 + 16.0);
        [self.contentView addSubview:fart];
    }
    return self;
}

@end
