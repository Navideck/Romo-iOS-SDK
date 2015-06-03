//
//  RMLookAction.h
//  Romo
//
//  Created on 12/2/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import <Foundation/Foundation.h>

#import "RMRomo.h"

@interface RMLookAction : NSObject

@property (nonatomic) float duration;

+ (id)actionWithLocation:(RMPoint3D)loc
             forDuration:(float)duration
                withRomo:(RMRomo *)romo;

- (void)execute;

@end
