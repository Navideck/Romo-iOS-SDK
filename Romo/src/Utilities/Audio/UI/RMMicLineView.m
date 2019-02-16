//
//  RMMicLineView.m
//  Romo
//
//  Created on 10/29/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import "RMMicLineView.h"

#import <Romo/RMMath.h>

#import "UIColor+RMColor.h"
#import "UIView+Additions.h"

#define kDBOffset     74.0

#define kIdleColor      [UIColor colorWithWhite:0.67 alpha:0.6]
#define kRecordingColor [UIColor colorWithHue:0.0 saturation:0.42 brightness:1.0 alpha:0.6]

//==============================================================================
@interface RMMicLineView ()

@property (nonatomic, strong) UIImageView *micLevelView;

@end

//==============================================================================
@implementation RMMicLineView

//------------------------------------------------------------------------------
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self addSubview:self.micLevelView];
    }
    return self;
}

//------------------------------------------------------------------------------
- (void)setLevel:(float)dbLevel
{
    int pixelsWide = CLAMP(kDBOffset-30, dbLevel - 5.0 + (kDBOffset*2), (kDBOffset*1.6));
    self.micLevelView.size = CGSizeMake(pixelsWide, pixelsWide);
    self.micLevelView.layer.cornerRadius = pixelsWide / 2.0;
    self.micLevelView.center = self.boundsCenter;
}

//------------------------------------------------------------------------------
- (void)setState:(RMMicState)state
{
    if (_state != state) {
        _state = state;
        
        switch (_state) {
            case RMMicState_Sampling:
                self.micLevelView.backgroundColor = kIdleColor;
                break;
            case RMMicState_Recording:
                self.micLevelView.backgroundColor = kRecordingColor;
                break;
        }
    }
}

#pragma mark - Helpers
//------------------------------------------------------------------------------
- (UIView *)micLevelView
{
    if (!_micLevelView) {
        _micLevelView = [[UIImageView alloc] initWithFrame:self.bounds];
        _micLevelView.backgroundColor = kIdleColor;
        _micLevelView.image = [UIImage imageNamed:@"micIcon"];
        _micLevelView.contentMode = UIViewContentModeCenter;
        _micLevelView.alpha = 0.9f;
        _micLevelView.layer.borderColor = [UIColor purpleColor].CGColor;
        _micLevelView.layer.borderWidth = 2.0f;
        _micLevelView.clipsToBounds = YES;
        _micLevelView.layer.cornerRadius = self.width / 2.0;
    }
    return _micLevelView;
}

@end
