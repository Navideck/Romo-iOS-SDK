//
//  RMCoreLeakyIntegrator.h
//  Romo3
//
//  Created on 8/29/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - constants
#define RM_LEAKY_INTGERATOR_LEEWAY_PERCENTAGE   0.05

#pragma mark - data types

// handler used to acquire input data for the integrator
typedef double (^RMCoreLeakyIntegratorInputSourceHandler)(void);

// handler that receives the output of the controller
typedef void (^RMCoreLeakyIntegratorOutputSinkHandler)(float value);


#pragma mark - Class Public Interface
@interface RMCoreLeakyIntegrator : NSObject

#pragma mark - properties
@property (nonatomic, getter=isEnabled) BOOL enabled;        // denotes if integrator is active
@property (nonatomic, readonly) float updateFrequency;       // frequency at which data is
                                                             // input to the integrator
@property (nonatomic) float leakRate;                        // rate at which value is subtracted
                                                             // from integrator (per second)
@property (nonatomic, readonly) float value;                 // current value of leaky integration
@property (nonatomic) float maxValue;                        // maximum integration value
@property (nonatomic) float minValue;                        // minimum integration value

- (id) initWithFrequency:(float)updateFrequency
                leakRate:(float)leakRate
                maxValue:(float)maxValue
                minValue:(float)minValue
             inputSource:(RMCoreLeakyIntegratorInputSourceHandler)inputSource
              outputSink:(RMCoreLeakyIntegratorOutputSinkHandler)outputSink;

- (void) resetIntegrator;                                    // clear persistent data

@end
