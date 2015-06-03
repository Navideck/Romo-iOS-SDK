//
//  RMMicLineView.h
//  Romo
//
//  Created on 10/29/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import <UIKit/UIKit.h>

typedef enum {
    RMMicState_Sampling,
    RMMicState_Recording
} RMMicState;

//==============================================================================
@interface RMMicLineView : UIView

@property (nonatomic) BOOL animating;
@property (nonatomic) RMMicState state;

- (void)setLevel:(float)dbLevel;

@end
