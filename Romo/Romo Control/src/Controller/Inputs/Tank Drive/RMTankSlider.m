//
//  RUITankSlider.m
//  Romo
//

#import "RMTankSlider.h"
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"
#import <Romo/RMMath.h>

@interface RMTankSlider ()

@property (nonatomic, strong) UIImageView *track;
@property (nonatomic, strong) UIImageView *handle;

@end

@implementation RMTankSlider

+ (id)tankSlider {
    if (iPad) {
        return [[RMTankSlider alloc] initWithFrame:CGRectMake(0, 0, 90, 250)];
    } else {
        return [[RMTankSlider alloc] initWithFrame:CGRectMake(0, 0, 68, 160)];
    }
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.track];
        [self addSubview:self.handle];
        
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDidPan:)];
        [self addGestureRecognizer:panGesture];
    }
    return self;
}

- (void)layoutSubviews
{
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    
    self.track.frame = CGRectMake((self.width - self.track.width) / 2, 0, self.track.width, self.height);
    self.handle.center = center;
}

- (void)setValue:(CGFloat)value {
    if (_value != value) {
        _value = value;
        [self.delegate slider:self didChangeToValue:value];
    }
}

- (void)handleDidPan:(UIPanGestureRecognizer *)gesture
{
    switch (gesture.state) {
        case UIGestureRecognizerStateChanged: {
            CGPoint point = [gesture locationInView:self];
            CGFloat y = CLAMP(0.0, point.y, self.height);
            
            self.handle.centerY = y;
            self.value = ((self.height / 2.0) - y) / (self.height / 2.0);
        } break;
            
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            self.value = 0;
            
            [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
                self.handle.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
            } completion:nil];
        } break;
            
        default: break;
    }
}

#pragma mark - Subview Getters

- (UIImageView *)track
{
    if (!_track) {
        _track = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"drive-control-tank-track"] resizableImageWithCapInsets:UIEdgeInsetsMake(12, 0, 12, 0)]];
        _track.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    }
    return _track;
}

- (UIImageView *)handle
{
    if (!_handle) {
        _handle = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"drive-control-tank-handle"]];
    }
    return _handle;
}

@end
