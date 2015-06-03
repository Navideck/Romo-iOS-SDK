//
//  RMCharacterPupil.m
//  RMCharacter
//

#import "RMCharacterPupil.h"
#import "RMMath.h"
#import <QuartzCore/QuartzCore.h>

#define DEFAULT_PUPIL_SIZE  29.0
#define PUPIL_MULT_MIN      0.5
#define PUPIL_MULT_MAX      1.25

@implementation RMCharacterPupil

+ (id)pupil
{
    return [[RMCharacterPupil alloc] initWithFrame:CGRectMake(0, 0, DEFAULT_PUPIL_SIZE, DEFAULT_PUPIL_SIZE)];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    super.frame = frame;
    self.layer.cornerRadius = frame.size.height/2;
}

- (void)setDilation:(CGFloat)dilation
{
    _dilation = CLAMP(PUPIL_MULT_MIN, dilation, PUPIL_MULT_MAX);
    CGPoint center = self.center;
    self.frame = CGRectMake(0, 0, DEFAULT_PUPIL_SIZE*_dilation, DEFAULT_PUPIL_SIZE*_dilation);
    self.center = center;
}

@end
