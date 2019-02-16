//
//  RMCreatureOneRobotController.m
//  Romo
//
//  Created on 9/5/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMJuvenileCreatureRobotController.h"
#import "RMProgressManager.h"
#import "RMAppDelegate.h"
#import "RMInteractionScriptRuntime.h"
#import "RMMissionRuntime.h"
#import <Romo/RMMath.h>

#define kBoredTimeout           19.0
#define kMissionPromptTimeout   31.0

@interface RMJuvenileCreatureRobotController ()

@end

@implementation RMJuvenileCreatureRobotController

//------------------------------------------------------------------------------
- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    if (self.currentStoryElementHasBeenRevealed) {
        [self _promptForMission];
    }
    
    // Start bored timer
    [self.boredTimer invalidate];
    [self.missionPromptTimer invalidate];
    self.boredTimer = [NSTimer scheduledTimerWithTimeInterval:kBoredTimeout
                                                       target:self
                                                     selector:@selector(_doBoredEvent)
                                                     userInfo:nil
                                                      repeats:NO];
}

//------------------------------------------------------------------------------
- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    
    [self.boredTimer invalidate];
    [self.missionPromptTimer invalidate];
}

//------------------------------------------------------------------------------
- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    // Don't allow equilibrioception yet
    return RMRomoFunctionalityBroadcasting | RMRomoFunctionalityCharacter;
}

//------------------------------------------------------------------------------
- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    return RMRomoInterruptionAll;
}

#pragma mark - Private Helpers
//------------------------------------------------------------------------------
- (void)_promptForMission
{
    // Invalidate all timers
    [self.missionPromptTimer invalidate];
    
    // If we're not sleeping, present the controls
    if (self.Romo.character.emotion != RMCharacterEmotionSleeping) {
        self.attentive = YES;
    }
    
    // Retrigger!
    self.missionPromptTimer = [NSTimer scheduledTimerWithTimeInterval:kMissionPromptTimeout
                                                               target:self
                                                             selector:@selector(_promptForMission)
                                                             userInfo:nil
                                                              repeats:NO];
}

//------------------------------------------------------------------------------
- (void)_doBoredEvent
{
    [self.boredTimer invalidate];
    
    if (self.chapterProgress == 0) {
        // Don't do anything if we haven't started any missions
        return;
    }
    
    if (self.chapterProgress == kCanDriveSquareMission && self.idleMovementEnabled) {
        // Execute the user-trained square
        [self _driveInSquare];
    } else {
        // Tilt around
        if ([self creatureCanTilt]) {
            self.tilting = YES;
            int numTimes = 3 + (self.chapterProgress / 10);
            int randomAngle = (arc4random() % 20) + 5;
            [self _tiltUpAndDown:numTimes withAngle:randomAngle];
        }
        
        // Do a little turn routine
        if ([self creatureCanTurn] && (randFloat() < 0.75) && self.idleMovementEnabled) {
            int numTimes = 3 + (self.chapterProgress / 5);
            int randomAngle = (arc4random() % 30) + 10;
            [self _rotate:numTimes withAngle:randomAngle];
        } else if ([self creatureCanDrive] && self.idleMovementEnabled) {
            int numTimes = 2 + (self.chapterProgress / 2);
            float randomSpeed = CLAMP(0.4, randFloat(), 0.7);
            [self _moveBackAndForward:numTimes withSpeed:randomSpeed];
        } else {
            NSArray *random = @[@(RMCharacterExpressionBored),
                                @(RMCharacterExpressionCurious),
                                @(RMCharacterExpressionLookingAround),
                                @(RMCharacterExpressionTalking),
                                @(RMCharacterExpressionPonder)];
            
            enableRomotions(self.idleMovementEnabled, self.Romo);

            [self.Romo.character setExpression:[self randomExpression:random]
                                   withEmotion:RMCharacterEmotionHappy];
            [self.Romo.character say:NSLocalizedString(@"Sweeeeeet!", @"Exited expression")];
        }
       
        // Retrigger!
        self.boredTimer = [NSTimer scheduledTimerWithTimeInterval:kBoredTimeout
                                                           target:self
                                                         selector:@selector(_doBoredEvent)
                                                         userInfo:nil
                                                          repeats:NO];
    }
}

//------------------------------------------------------------------------------
- (void)_driveInSquare
{
    void (^completion)(BOOL) = ^(BOOL finished) {
        if (finished) {
            NSArray *random = @[@(RMCharacterExpressionExcited),
                                @(RMCharacterExpressionHappy),
                                @(RMCharacterExpressionProud),
                                @(RMCharacterExpressionLaugh)];
            
            [self.Romo.character setExpression:[self randomExpression:random]
                                   withEmotion:RMCharacterEmotionHappy];
            
            // Retrigger!
            self.boredTimer = [NSTimer scheduledTimerWithTimeInterval:kBoredTimeout
                                                               target:self
                                                             selector:@selector(_doBoredEvent)
                                                             userInfo:nil
                                                              repeats:NO];
        }
    };
    [RMMissionRuntime runUserTrainedAction:RMUserTrainedActionDriveInASquare
                                    onRomo:self.Romo
                                completion:completion];
}

@end
