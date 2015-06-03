//
//  RMCoreLeakyIntegrator.m
//  Romo3
//
//  Created on 8/29/13.
//  Copyright (c) 2013 Romotive. All rights reserved.

#import "RMCoreLeakyIntegrator.h"
#import <RMShared/RMMath.h>
#import <RMShared/RMDispatchTimer.h>

#pragma mark - "private interface"

@interface RMCoreLeakyIntegrator()

// block handler, to be used for getting new data into the filter
@property (nonatomic, copy) RMCoreLeakyIntegratorInputSourceHandler inputSource;
@property (nonatomic, copy) RMCoreLeakyIntegratorOutputSinkHandler outputSink;

// timer used to execute integration update
@property (nonatomic, strong) RMDispatchTimer *updateLoopTimer;

@end


#pragma mark - class implementation

@implementation RMCoreLeakyIntegrator

- (id)initWithFrequency:(float)updateFrequency
               leakRate:(float)leakRate
               maxValue:(float)maxValue
               minValue:(float)minValue
            inputSource:(RMCoreLeakyIntegratorInputSourceHandler)inputSource
             outputSink:(RMCoreLeakyIntegratorOutputSinkHandler)outputSink
{
    self = [super init];
    
    if(self)
    {
        _enabled = NO;
        _updateFrequency = updateFrequency;
        _leakRate = leakRate;
        _maxValue = maxValue;
        _minValue = minValue;
        _inputSource = inputSource;
        _outputSink = outputSink;

        __weak RMCoreLeakyIntegrator *weakSelf = self;
        self.updateLoopTimer = [[RMDispatchTimer alloc] initWithName:@"com.romotive.LeakyIntegratorQueue"
                                                           frequency:self.updateFrequency];
        self.updateLoopTimer.eventHandler = ^{
            [weakSelf updateIntegrator];
        };
        [self.updateLoopTimer startRunning];
    }
    
    return  self;
}

#pragma mark - setters

- (void)enabled:(BOOL)enabled
{
    _enabled = enabled;
    if (enabled) {
        [self.updateLoopTimer startRunning];
    } else {
        [self.updateLoopTimer stopRunning];
    }
}

- (void)maxValue:(float)maxValue
{
    _maxValue = maxValue;
    if(self.value > maxValue) {_value = maxValue;}
}

- (void)minValue:(float)minValue
{
    _minValue = minValue;
    if(self.value < minValue) {_value = minValue;}
}

#pragma mark - core methods

// restart integrator
- (void)resetIntegrator
{
    // clear the integration value
    _value = 0;
}

// change the frequency that the integrator updates at
- (void)updateFrequency:(float)frequency
{
    // set frequency and update the dispatch timer
    _updateFrequency = frequency;
    
    self.updateLoopTimer.frequency = frequency;
}

// acquire and update the latest value of the filter
- (void) updateIntegrator
{
    // integrate in
    _value += self.inputSource();
 
    // leak out
    _value -= (self.leakRate/self.updateFrequency);
    
    // enforce range limits
    _value = CLAMP(self.minValue, self.value, self.maxValue);
    
    // callback to integrator creator
    self.outputSink(self.value);
   }

@end
