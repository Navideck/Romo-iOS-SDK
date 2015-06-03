//
//  RMMotivationManager.m
//  Romo
//
//  Created on 7/22/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMMotivationManager.h"

#define kMotivationStepSize 1.0

static const RMMotivation initialMotivation = RMMotivation_SocialDrive;

@interface RMMotivationManager ()

@property (nonatomic, strong) RMCharacter    *character;
@property (nonatomic, strong) NSMutableArray *motivationalDrives;

@end

@implementation RMMotivationManager

//------------------------------------------------------------------------------
-(id)initWithCharacter:(RMCharacter *)character
{
    self = [super init];
    if (self) {
        _character = character;
        _motivation = initialMotivation;
        _motivationalDrives = [[NSMutableArray alloc] initWithCapacity:RMMotivation_Count];
        for (int i = 0; i < RMMotivation_Count; i++) {
            [_motivationalDrives addObject:[NSNumber numberWithFloat:0.0f]];
        }
        _behaviorManager = [[RMBehaviorManager alloc] initWithMotivation:initialMotivation];
        switch(_motivation) {
            case RMMotivation_SocialDrive:
                _character.emotion = RMCharacterEmotionHappy;
                break;
            case RMMotivation_Curiosity:
                _character.emotion = RMCharacterEmotionCurious;
                break;
            case RMMotivation_Sleep:
                _character.emotion = RMCharacterEmotionSleeping;
                break;
            default:
                break;
        }
    }
    return self;
}

//------------------------------------------------------------------------------
-(void)resetDrives
{
    [self.motivationalDrives removeAllObjects];
    for (int i = 0; i < RMMotivation_Count; i++) {
        [self.motivationalDrives addObject:[NSNumber numberWithFloat:0.0f]];
    }
}

//------------------------------------------------------------------------------
-(void)activateMotivation:(RMMotivation)motivation
{
    [self.motivationalDrives replaceObjectAtIndex:motivation
                                       withObject:[NSNumber numberWithFloat:([[self.motivationalDrives objectAtIndex:motivation] floatValue] + kMotivationStepSize)]];
}

//------------------------------------------------------------------------------
-(RMMotivation)highestMotivationalDrive
{
    RMMotivation highestMotivationIndex = RMMotivation_Count;
    if (self.motivationalDrives.count == 0) {
        return highestMotivationIndex;
    } else {
        float highestDrive = [[self.motivationalDrives objectAtIndex:0] floatValue];
        highestMotivationIndex = 0;
        for (int i = 1; i < self.motivationalDrives.count; i++) {
            float currentDrive = [[self.motivationalDrives objectAtIndex:i] floatValue];
            
            if (currentDrive > highestDrive) {
                highestDrive = currentDrive;
                highestMotivationIndex = i;
            }
        }
        return highestMotivationIndex;
    }
    
}

//------------------------------------------------------------------------------
-(void)setMotivation:(RMMotivation)motivation
{
    _motivation = motivation;
    switch(self.motivation) {
        case RMMotivation_SocialDrive:
            self.behaviorManager.behavior = RMBehavior_TrackPerson;
            self.character.emotion = RMCharacterEmotionHappy;
            break;
        case RMMotivation_Curiosity:
            self.behaviorManager.behavior = RMBehavior_BeBored;
            if (arc4random_uniform(1)) {
                self.character.emotion = RMCharacterEmotionCurious;
            } else {
                if (arc4random_uniform(1)) {
                    self.character.emotion = RMCharacterEmotionBewildered;
                } else {
                    self.character.emotion = RMCharacterEmotionIndifferent;
                }
            }
            self.character.emotion = RMCharacterEmotionCurious;
            break;
        case RMMotivation_Sleep:
            self.behaviorManager.behavior = RMBehavior_Sleep;
            self.character.emotion = RMCharacterEmotionSleeping;
            break;
        default:
            break;
    }
}

//------------------------------------------------------------------------------
-(NSArray *)getDrives
{
    return [NSArray arrayWithArray:self.motivationalDrives];
}

@end
