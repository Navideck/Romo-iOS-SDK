//
//  RMDriveTiltSlider.m
//  Romo
//
//  Created on 11/19/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMDriveTiltSlider.h"
#import "UIView+Additions.h"
#import <Romo/RMMath.h>

@interface RMDriveTiltSlider ()

// Readonly public overrides
@property (nonatomic, assign, readwrite) RMDriveTiltSliderValue value;

// Subviews
@property (nonatomic, strong) UIImageView *trackView;
@property (nonatomic, strong) UIImageView *handleView;

@end

@implementation RMDriveTiltSlider

+ (id)tiltSlider
{
    return [[RMDriveTiltSlider alloc] initWithFrame:CGRectMake(0, 0, 43, 140)];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _value = RMDriveTiltSliderValueCenter;
        
        _trackView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"drive-telepresence-tilt-track"]];
        self.trackView.center = self.boundsCenter;
        [self addSubview:self.trackView];
        
        _handleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"drive-control-tank-handle"]];
        self.handleView.center = self.center;
        [self addSubview:self.handleView];
        
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:panGesture];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture
{
    CGPoint location = [gesture locationInView:self];
    CGFloat slideToPoint;
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            self.handleView.centerY = CLAMP(0.0, location.y, self.height);
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            slideToPoint = 0;
            
            [self updateValueBasedOnHandlePosition];
            
            switch (self.value) {
                case RMDriveTiltSliderValueUp:
                    slideToPoint = 10;
                    break;
                    
                case RMDriveTiltSliderValueCenter:
                    slideToPoint = self.boundsCenter.y;
                    break;
                    
                case RMDriveTiltSliderValueDown:
                    slideToPoint = 128;
                    break;
            }
            
            [UIView animateWithDuration:0.1 animations:^{
                self.handleView.centerY = slideToPoint;
            }];
            
            break;
        }
            
        default:
            break;
    }
}

- (void)updateValueBasedOnHandlePosition
{
    if (self.handleView.centerY < self.height / 3.0) {
        if (self.value != RMDriveTiltSliderValueUp) {
            self.value = RMDriveTiltSliderValueUp;
        }
    } else if (self.handleView.centerY < 2 * (self.height / 3.0)) {
        if (self.value != RMDriveTiltSliderValueCenter) {
            self.value = RMDriveTiltSliderValueCenter;
        }
    } else {
        if (self.value != RMDriveTiltSliderValueDown) {
            self.value = RMDriveTiltSliderValueDown;
        }
    }
}

@end
