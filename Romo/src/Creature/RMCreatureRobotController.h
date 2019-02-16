//
//  RMCreatureRobotController.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMActivityRobotController.h"
#import "RMMotivationManager.h"
#import "RMProgressManager.h"
#import <Romo/RMVision.h>

// Chapter 1 missions
#define kCanDriveMission        1
#define kCanTurnMission         3
#define kCanDriveSquareMission  7
#define kCanTiltMission         8
#define kRomotionTangoMission   10

// Chapter 2 missions
#define kPokeMission            1
#define kTickleMission          2
#define kReactToFacesMission    3
#define kFartOnShakeMission     5
#define kPickUpPutDownMission   6

// Chapter 3 missions
#define kLoudSoundsMission      1
#define kDetectMotionMission    2

@interface RMCreatureRobotController : RMActivityRobotController

// A place to store our robot
@property (nonatomic, weak) RMCoreRobotRomo3 *robot;

// Timers
@property (nonatomic, strong) NSTimer *boredTimer;
@property (nonatomic, strong) NSTimer *sleepTimer;
@property (nonatomic, strong) NSTimer *missionPromptTimer;

// Motivation
@property (nonatomic, strong) RMMotivationManager *motivationManager;

// Story
@property (nonatomic) BOOL currentStoryElementHasBeenRevealed;
@property (nonatomic) RMStoryElement *currentStoryElement;
@property (nonatomic) int chapterProgress;

// Whether the creature is picked up or not
@property (nonatomic) BOOL isPickedUp;
@property (nonatomic) BOOL tilting;

// Whether the creature should be listening for audio
@property (nonatomic) BOOL listening;

// User Set Idle Movement preference
@property (nonatomic) BOOL idleMovementEnabled;

// Helpers
- (RMCharacterExpression)randomExpression:(NSArray *)expressions;
- (void)say:(NSString *)say;
- (void)doSleepyTick;

// Story elements
- (BOOL)hasStoryElementForMission:(int)mission inChapter:(RMChapter)chapter;
- (BOOL)hasStoryElementForScript:(NSString *)scriptName;
- (NSString *)filenameForMission:(int)mission inChapter:(RMChapter)chapter;

// Helpers for creature capabilities
- (BOOL)creatureCanDrive;
- (BOOL)creatureCanTilt;
- (BOOL)creatureCanTurn;
- (BOOL)creatureKnowsRomotionTango;
- (BOOL)creatureShouldFartOnShake;
- (BOOL)creatureDetectsFaces;
- (BOOL)creatureRespondsToLoudSounds;
- (BOOL)creatureDetectsMotion;

// Behavioral helpers
- (void)_rotate:(int)numTimes
      withAngle:(int)angle;
- (void)_moveBackAndForward:(int)numTimes
                  withSpeed:(float)speed;
- (void)_tiltUpAndDown:(int)numTimes
             withAngle:(int)angle;

/**
 If we're picked up, disables Romotions;
 Else, enables Romotions
 */
- (void)disableRomotionsIfPickedUp;

@end
