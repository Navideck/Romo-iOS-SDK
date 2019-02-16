//
//  RMMotivationManager.h
//  Romo
//
//  Created on 7/22/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Romo/RMCharacter.h>
#import "RMBehaviorManager.h"
#import "RMBehaviorMotivationTypes.h"

/**
 Manages a character's motivations
 */
@interface RMMotivationManager : NSObject

@property (nonatomic) RMMotivation motivation;
@property (nonatomic, strong) RMBehaviorManager *behaviorManager;

-(id)initWithCharacter:(RMCharacter *)character;

-(void)resetDrives;
-(void)activateMotivation:(RMMotivation)motivation;

-(NSArray *)getDrives;
-(RMMotivation)highestMotivationalDrive;

@end
