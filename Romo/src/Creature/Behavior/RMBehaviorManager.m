//
//  RMBehaviorManager.m
//  Romo
//
//  Created on 7/22/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMBehaviorManager.h"

@interface RMBehaviorManager ()

@property (nonatomic, strong) NSMutableArray *behaviors;
@property (nonatomic) RMMotivation motivation;

@end

@implementation RMBehaviorManager

//------------------------------------------------------------------------------
- (id)initWithMotivation:(RMMotivation)motivation
{
    self = [super init];
    if (self) {
        switch (motivation) {
            case RMMotivation_SocialDrive:
                _behavior = RMBehavior_TrackPerson;
                break;
            case RMMotivation_Curiosity:
                _behavior = RMBehavior_BeBored;
                break;
            case RMMotivation_Sleep:
                _behavior = RMBehavior_Sleep;
                break;
            default:
                DDLogVerbose(@"ERROR: Initializing RMBehaviorManager with invalid motivation");
        }
        _motivation = motivation;
    }
    return self;
}

@end
