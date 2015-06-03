//
//  RMFreezeDanceBehavior.h
//  Romo
//
//  Created on 12/5/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RMRomo;

@interface RMFreezeDanceBehavior : NSObject

@property (nonatomic, strong) RMRomo *Romo;

@property (nonatomic, getter=isDancing, readonly) BOOL dancing;
@property (nonatomic) float duration;   // Duration in seconds
@property (nonatomic) BOOL recordVideo; // Records video if set to true before starting

@property (nonatomic, copy) void (^completion)(BOOL finished);

- (id)initWithRomo:(RMRomo *)romo;

- (void)start;
- (void)stop;

@end
