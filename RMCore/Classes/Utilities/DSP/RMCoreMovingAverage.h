//
//  RMCoreMovingAverage.h
//  Romo3
//
//  Created on 2/11/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
// This module provides a simple moving average filter.
// <http://en.wikipedia.org/wiki/Moving_average>
//
// Note: The window size is not currently adjustable after the filter is
//       created, but it will be in the future.
//

#import <Foundation/Foundation.h>

#pragma mark - constants

// percent off that the PID Controller frequency can be (assuming GCD holds to
// this request...)
#define LEEWAY_PERCENTAGE       0.05

#pragma mark - data types

// handler used to acquire input data for the filter
typedef double (^RMCoreMovingAverageInputSourceHandler)(void);

#pragma mark - Class Public Interface
@interface RMCoreMovingAverageSimple : NSObject

#pragma mark - properties
@property (atomic, readonly, getter=isEnabled) BOOL enabled; // denotes if filter is active
@property (nonatomic) float filterFrequency;                 // frequency at which data is
                                                             // input to the filter

#pragma mark - factory methods
// use this factory method to generate the simple moving average filter
+ (id) createFilterWithFrequency:(float)updateRate windowSize:(int)windowSize
            inputSource: (RMCoreMovingAverageInputSourceHandler)inputSourceHandler;

#pragma mark - data accesors
- (double) getFilterValue;                     // most up-to-date value

#pragma mark - class guts
- (void) enableFilter;                         // activate filter
- (void) disableFilter;                        // deactivate filter
- (void) resetFilter;                          // clear persistent data
//- (void) newWindowSize:(int)windowSize;        // change the filter window size

@end
