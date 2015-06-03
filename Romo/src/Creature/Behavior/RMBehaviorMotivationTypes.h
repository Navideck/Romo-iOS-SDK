//
//  RMBehaviorMotivationTypes.h
//  Romo
//
//  Created on 8/6/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#ifndef Romo_RMBehaviorMotivationTypes_h
#define Romo_RMBehaviorMotivationTypes_h

/**
 Defines the motivations
 */
typedef enum {
    /// Drives the character towards social interaction
    RMMotivation_SocialDrive    = 0,
    /// Drives the character to investigate perceptually stimulating objects
    RMMotivation_Curiosity      = 1,
    /// Drives the character to sleep
    RMMotivation_Sleep          = 2,
    /// Indicates the number of motivational states
    RMMotivation_Count
} RMMotivation;

/**
 Defines the possible high-level behaviors
 */
typedef enum {
    /// Track a user
    RMBehavior_TrackPerson  = 0,
    /// Mimic a user
    RMBehavior_MimicPerson  = 1,
    /// Look around
    RMBehavior_LookAround   = 2,
    /// Track Motion
    RMBehavior_TrackMotion  = 3,
    /// Be Scared
    RMBehavior_BeScared     = 4,
    /// Be Bored
    RMBehavior_BeBored      = 5,
    /// Go to sleep
    RMBehavior_Sleep        = 6,
    
    /// Indicates the number of behaviors
    RMBehavior_Count
} RMBehavior;



#endif
