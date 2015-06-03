//
//  RMLookAction.m
//  Romo
//
//  Created on 12/2/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMLookAction.h"

@interface RMLookAction ()

@property (nonatomic) RMPoint3D loc;
@property (nonatomic, weak) RMRomo *romo;

@end

@implementation RMLookAction

+ (id)actionWithLocation:(RMPoint3D)loc
             forDuration:(float)duration
                withRomo:(RMRomo *)romo
{
    RMLookAction *action = [[RMLookAction alloc] init];
    action.loc = loc;
    action.duration = duration;
    action.romo = romo;
    
    return action;
}

- (void)execute
{
    [self.romo.character lookAtPoint:self.loc animated:YES];
}

@end
