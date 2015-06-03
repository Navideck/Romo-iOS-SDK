//
//  RMSquareActionIcon.m
//  Romo
//

#import "RMSquareActionIcon.h"
#import "UIView+Additions.h"
#import <QuartzCore/QuartzCore.h>

@implementation RMSquareActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UIView *square = [[UIView alloc] initWithFrame:CGRectMake(20, 20, self.contentView.width - 40, self.contentView.height - 40)];
        square.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        square.layer.borderWidth = 4;
        square.layer.borderColor = [UIColor whiteColor].CGColor;
        [self.contentView addSubview:square];
    }
    return self;
}

@end
