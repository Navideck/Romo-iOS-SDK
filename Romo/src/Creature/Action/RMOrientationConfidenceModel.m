//
//  RMOrientationConfidenceModel.m
//  Romo
//
//  Created on 7/18/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMOrientationConfidenceModel.h"

#define kOrientationBins      360
#define kRelaxationUpdateRate 1

@interface RMOrientationConfidenceModel () {
    int _degrees[kOrientationBins];
}

@property (nonatomic, strong) NSTimer *timer;

@end

@implementation RMOrientationConfidenceModel

//------------------------------------------------------------------------------
- (id)init
{
    self = [super init];
    if (self) {
        [self resetConfidences];
    }
    return self;
}

//------------------------------------------------------------------------------
- (void)objectSeenAt:(float)location
{
    int loc = (int)location;
    if (loc < kOrientationBins) {
        _degrees[loc] += 1;
    }
}

//------------------------------------------------------------------------------
- (int)mostProbableLocation
{
    int highestConfidence = -1;
    int highestConfidenceIndex = -1;
    for (int i = 0; i < kOrientationBins; i++) {
        float currentConfidence = _degrees[i];
        if (currentConfidence > highestConfidence) {
            highestConfidence = currentConfidence;
            highestConfidenceIndex = i;
        }
    }
    return highestConfidenceIndex;
}

//------------------------------------------------------------------------------
- (void)resetConfidences
{
    [self.timer invalidate];
    for (int i = 0; i < kOrientationBins; i++) {
        _degrees[i] = 0;
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:kRelaxationUpdateRate
                                                  target:self
                                                selector:@selector(relaxConfidences)
                                                userInfo:nil
                                                 repeats:YES];
}

//------------------------------------------------------------------------------
- (void)relaxConfidences
{
    for (int i = 0; i < kOrientationBins; i++) {
        if (_degrees[i] && _degrees[i] > 0) {
            _degrees[i] -= 1;
        }
    }
}

//------------------------------------------------------------------------------
- (void)stop
{
    [self.timer invalidate];
    self.timer = nil;
}

@end
