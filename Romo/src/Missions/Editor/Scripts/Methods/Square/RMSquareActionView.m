//
//  RMSquareActionView.m
//  Romo
//

#import "RMSquareActionView.h"
#import "UIView+Additions.h"

@implementation RMSquareActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UIView *square = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 68, 68)];
        square.backgroundColor = [UIColor clearColor];
        square.layer.borderWidth = 4;
        square.layer.borderColor = [UIColor whiteColor].CGColor;
        square.center = CGPointMake(self.contentView.width / 2.0, self.contentView.height / 2.0 + 12);
        [self.contentView addSubview:square];
    }
    return self;
}

@end
