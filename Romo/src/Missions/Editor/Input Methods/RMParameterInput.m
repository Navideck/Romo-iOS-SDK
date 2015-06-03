//
//  RMParameterInput.m
//  Romo
//

#import "RMParameterInput.h"
#import "UIView+Additions.h"
#import <QuartzCore/QuartzCore.h>
#import "RMListInput.h"
#import "RMTimeInput.h"

@implementation RMParameterInput

//static const CGFloat bottomOffset = 8;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

#pragma mark - Public Methods

- (void)setParameter:(RMParameter *)parameter
{
    _parameter = parameter;
    self.value = parameter.value;
}

@end
