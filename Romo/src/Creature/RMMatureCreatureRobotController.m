//
//  RMMatureCreatureRobotController.m
//  Romo
//
//  Created on 9/5/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMMatureCreatureRobotController.h"

#import <Romo/RMVision.h>
#import <Romo/RMImageUtils.h>
#import <Romo/RMVisionDebugBroker.h>
#import <Romo/RMMotionDetectionModule.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "RMTracker.h"
#import <Romo/RMMath.h>

#import "RMSoundEffect.h"
#import "RMMissionRuntime.h"

#define kBoredTimeout           17.0
#define kSleepTimeout           160.0

static const float kFaceCloseTimeout = 20.0;
static const float kFaceCloseDistance = 18.0;

static const float kLookMirrorTurnDegrees = 60;

/** Way less sensitive to motion in Creature mode */
static const float motionDetectionPercentOfPixelsMovingThreshold = 4.5; // percent
static const int motionDetectionConsecutiveTriggerCount = 10; // # of frames

@interface RMMatureCreatureRobotController () <RMTrackerDelegate, RMMotionDetectionModuleDelegate>

@property (nonatomic, strong) RMTracker *tracker;

@property (nonatomic) double lastFaceCloseResponse;
@property (nonatomic) BOOL sleepy;

@property (nonatomic, strong) RMMotionDetectionModule *motionDetectionModule;

@property (nonatomic, getter=isDoingBoredEvent) BOOL doingBoredEvent;

@end

@implementation RMMatureCreatureRobotController

#pragma mark - Initialization / Teardown
//------------------------------------------------------------------------------
- (void)controllerWillBecomeActive
{
    [super controllerWillBecomeActive];
    
    if ([self creatureDetectsFaces]) {
        self.lastFaceCloseResponse = currentTime() - kFaceCloseTimeout;
    }
}

//------------------------------------------------------------------------------
- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    // Show a prompt if we've already executed our interaction script
    if (self.currentStoryElementHasBeenRevealed) {
        self.attentive = YES;
    }
    
    if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusNotDetermined) {
        // If we've never asked the user for permission to their photo library, ask them now
        // so we have an answer later on in the story
        [self requestPhotoLibraryPermission];
    }
    
    [self _scheduleCuriosityTimers];
    
    if ([self creatureDetectsFaces]) {
        self.tracker.Romo = self.Romo;
        self.tracker.delegate = self;
    }
}

//------------------------------------------------------------------------------
- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    
    [self.Romo.character setFaceRotation:0];
    
    [self.boredTimer invalidate];
    [self.sleepTimer invalidate];
    [self deactivateMotionDetection];

    _tracker.delegate = nil;
    _tracker = nil;
}

#pragma mark - RMRobotController Overrides
//------------------------------------------------------------------------------
- (NSSet *)initiallyActiveVisionModules
{
    if ([self creatureDetectsFaces]) {
        // Activate Face Detection
        return [NSSet setWithObjects:RMVisionModule_FaceDetection, nil];
    } else {
        return [super initiallyActiveVisionModules];
    }
}

//------------------------------------------------------------------------------
- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    RMRomoFunctionalities activeForCurrentProgress = super.initiallyActiveFunctionalities;

    // Does creature have vision?
    if ([self creatureDetectsFaces]) {
        activeForCurrentProgress = enableFunctionality(RMRomoFunctionalityVision, activeForCurrentProgress);
    }
    // Does creature respond to sounds?
    if ([self creatureRespondsToLoudSounds]) {
        activeForCurrentProgress = enableFunctionality(RMRomoFunctionalityLoudSound, activeForCurrentProgress);
    }
    return activeForCurrentProgress;
}

#pragma mark - Vision
// Faces
//------------------------------------------------------------------------------
-(void)didDetectFace:(RMFace *)face
{
    if (self.isDoingBoredEvent) {
        // Don't react if a bored event is running
        return;
    }

    [self.boredTimer invalidate];
    [self deactivateMotionDetection];

    // If we're asleep, just maybe do a tick
    if (self.motivationManager.motivation == RMMotivation_Sleep) {
        [self doSleepyTick];
        return;
    }
    // ...otherwise just invalidate your sleep timer
    else {
        [self.sleepTimer invalidate];
        self.sleepy = NO;
    }
    
    // Strengthen our social drive
    [self.motivationManager activateMotivation:RMMotivation_SocialDrive];
    
    // If we're curious, we should re-activate the social drive
    // This is overriding the intended functionality of the motivation manager for now,
    // but will be fixed in 2.7
    if (self.motivationManager.motivation == RMMotivation_Curiosity) {
        self.motivationManager.motivation = RMMotivation_SocialDrive;
    }
    
    // If we're driven by social interaction, respond to it appropriately
    if (self.motivationManager.motivation == RMMotivation_SocialDrive) {
        // Face just found! Get happy!
        if (face.justFound) {
            self.Romo.character.emotion = RMCharacterEmotionHappy;
        }
        
        // Laugh if the person is upside down
        if (face.advancedInfo && (face.rotation == 180 || face.rotation == -180)) {
            enableRomotions(self.idleMovementEnabled, self.Romo);
            if (arc4random_uniform(100) < 50) {
                self.Romo.character.expression = RMCharacterExpressionChuckle;
            } else {
                self.Romo.character.expression = RMCharacterExpressionLaugh;
            }
        }
        // Get scared if too close
        else if ((face.distance < kFaceCloseDistance) &&
                 ((currentTime() - self.lastFaceCloseResponse) > kFaceCloseTimeout)) {
            enableRomotions(self.idleMovementEnabled, self.Romo);
            [self.Romo.character setExpression:RMCharacterExpressionScared];
            
            self.lastFaceCloseResponse = currentTime();
        }
        // Track the face!
        else {
            [self.tracker trackObject:face];
            [self _mimic:face];
        }
    }
#ifdef CREATURE_DEBUG
    [[RMVisionDebugBroker shared] objectAt:face.boundingBox
                              withRotation:face.rotation
                                  withName:@"Face"];
#endif
}

//------------------------------------------------------------------------------
- (void)didLoseFace
{
    if (self.isDoingBoredEvent) {
        // Don't react if a bored event is running
        return;
    }
        
    if (self.motivationManager.motivation == RMMotivation_SocialDrive) {
        self.Romo.character.emotion = RMCharacterEmotionCurious;
    }
    // Set face rotation to be normal
    [self.Romo.character setFaceRotation:0];
    
    // If we're tracking a person, look for them
    if (self.motivationManager.behaviorManager.behavior == (RMBehavior_TrackPerson)) {
        [self.tracker lostTrackOfObject];
    }
    
    // Schedule sleep timer
    if (self.motivationManager.motivation != RMMotivation_Sleep) {
        [self _scheduleCuriosityTimers];
    }
    
#ifdef CREATURE_DEBUG
    [[RMVisionDebugBroker shared] loseObject:@"Face"];
#endif
}

#pragma mark - Tracker delegate
//------------------------------------------------------------------------------
-(void)didFindObject:(RMObject *)object
{
    NSLog(@"found object");
}

//------------------------------------------------------------------------------
-(void)didLoseTrackOfObject:(NSString *)object
{
    NSLog(@"Lost track");
}

#pragma mark - RMMotionDetectionModuleDelegate
//------------------------------------------------------------------------------
- (void)motionDetectionModuleDidDetectMotion:(RMMotionDetectionModule *)module
{
    if (!self.Romo.robot.isDriving && !self.Romo.robot.isTilting && !self.isDoingBoredEvent) {
        // Turn off the module because we don't want this to trigger again then sound an alarm
        [self deactivateMotionDetection];
        
        NSString *randomAlarmSound = [NSString stringWithFormat:@"alarmSound%d", arc4random() % 13];
        [RMSoundEffect playForegroundEffectWithName:randomAlarmSound repeats:NO gain:1.0];
    }
}

//------------------------------------------------------------------------------
- (void)motionDetectionModuleDidDetectEndOfMotion:(RMMotionDetectionModule *)module
{
    // stub
}

#pragma mark - Helpers

//------------------------------------------------------------------------------
- (void)_mimic:(RMFace *)face
{
    // If we have advanced face info, do stuff with it!
    [self _mimicRotation:face];
//    [self _mimicLookLocation:face];
}

//------------------------------------------------------------------------------
- (void)_mimicRotation:(RMFace *)face
{
    if (face.advancedInfo && !self.isDoingBoredEvent) {
        if (face.rotation > 0) {
            [self.Romo.character setFaceRotation:-7];
        } else if (face.rotation < 0) {
            [self.Romo.character setFaceRotation:7];
        } else {
            [self.Romo.character setFaceRotation:0];
        }
        return;
    }
}

//------------------------------------------------------------------------------
- (void)_mimicLookLocation:(RMFace *)face
{
    if (self.Romo.robot && self.Romo.RomoCanDrive && !self.isDoingBoredEvent) {
        float turnAngle = 0;
        if (face.profileAngle > 0 && face.profileAngle < 180) {
            turnAngle = kLookMirrorTurnDegrees;
        } else if (face.profileAngle > 180) {
            turnAngle = -kLookMirrorTurnDegrees;
        }
        if (turnAngle != 0) {
            [self.Romo.robot turnByAngle:turnAngle
                              withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                              completion:^(BOOL success, float heading) {
                                  double delayInSeconds = 2.0;
                                  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                                  dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                                      [self.Romo.robot turnToHeading:self.tracker.lastFaceLocation
                                                          withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                                                               speed:0.5
                                                   forceShortestTurn:YES
                                                     finishingAction:RMCoreTurnFinishingActionStopDriving
                                                          completion:nil];
                                  });
                              }];
        }
    }
}

//------------------------------------------------------------------------------
- (void)_doBoredEvent
{
    if (self.isDoingBoredEvent) {
        // If a blocking bored event is currently being executed, don't allow another one to start
        return;
    }
    
    [self.boredTimer invalidate];
    [self.motivationManager activateMotivation:RMMotivation_Curiosity];
    
    static const float kBoredSearchRatio          = 0.38f;
    static const float kBoredDoMoveRatio          = 0.30f;
    static const float kBoredDoRomotionTangoRatio = 0.02f;
    
    float seed = randFloat();
    if (seed <= kBoredSearchRatio) {
        // Do a random expression and prompt for a mission
        NSArray *randomExpressions = @[@(RMCharacterExpressionBored),
                                       @(RMCharacterExpressionCurious),
                                       @(RMCharacterExpressionLookingAround)];
        enableRomotions(self.idleMovementEnabled, self.Romo);
        RMCharacterExpression randomExpression = [self randomExpression:randomExpressions];
        self.Romo.character.expression = randomExpression;
        self.attentive = YES;
    } else if (seed <= kBoredSearchRatio + kBoredDoMoveRatio) {
        float nextSeed = randFloat();
        if (nextSeed < 0.33 && self.idleMovementEnabled) {
            int numTimes = 2 + arc4random_uniform(6);
            float randomSpeed = CLAMP(0.4, randFloat(), 0.7);
            [self _moveBackAndForward:numTimes withSpeed:randomSpeed];
        } else if (nextSeed < 0.67 && self.idleMovementEnabled) {
            int numTimes = 3 + arc4random_uniform(5);
            int randomAngle = (arc4random() % 30) + 10;
            [self _rotate:numTimes withAngle:randomAngle];
        } else {
            self.tilting = YES;
            int numTimes = arc4random_uniform(8);
            int randomAngle = (arc4random() % 20) + 5;
            [self _tiltUpAndDown:numTimes withAngle:randomAngle];
        }
    } else if (seed <= kBoredSearchRatio + kBoredDoMoveRatio + kBoredDoRomotionTangoRatio && self.idleMovementEnabled) {
        self.doingBoredEvent = YES;
        [RMMissionRuntime runUserTrainedAction:RMUserTrainedActionRomotionTangoWithMusic
                                        onRomo:self.Romo
                                    completion:^(BOOL finished) {
                                        self.doingBoredEvent = NO;
                                    }];
    } else {
        if ([self creatureShouldFartOnShake]) {
            // Do a random expression (with a bias towards farting)
            NSArray *randomExpressions = @[@(RMCharacterExpressionEmbarrassed),
                                           @(RMCharacterExpressionHoldingBreath),
                                           @(RMCharacterExpressionLaugh),
                                           @(RMCharacterExpressionFart),
                                           @(RMCharacterExpressionSneeze),
                                           @(RMCharacterExpressionSniff),
                                           @(RMCharacterExpressionFart),
                                           @(RMCharacterExpressionSleepy)];
            enableRomotions(self.idleMovementEnabled, self.Romo);
            RMCharacterExpression randomExpression = [self randomExpression:randomExpressions];
            self.Romo.character.expression = randomExpression;
        } else {
            // Do a random expression
            NSArray *randomExpressions = @[@(RMCharacterExpressionEmbarrassed),
                                           @(RMCharacterExpressionHoldingBreath),
                                           @(RMCharacterExpressionLaugh),
                                           @(RMCharacterExpressionPonder),
                                           @(RMCharacterExpressionSneeze),
                                           @(RMCharacterExpressionSniff),
                                           @(RMCharacterExpressionTalking),
                                           @(RMCharacterExpressionYawn)];
            enableRomotions(self.idleMovementEnabled, self.Romo);
            RMCharacterExpression randomExpression = [self randomExpression:randomExpressions];
            self.Romo.character.expression = randomExpression;
        }
        
        if (self.creatureDetectsMotion && !_motionDetectionModule) {
            // Activate motion detection if not already active but the creature knows how to detect it
            [self.Romo.vision activateModule:self.motionDetectionModule];
        }
    }
    
    // Set motivation to curiosity (will also set emotion)
    self.motivationManager.motivation = RMMotivation_Curiosity;
    
    // Otherwise, schedule a new bored event!
    self.boredTimer = [NSTimer scheduledTimerWithTimeInterval:kBoredTimeout
                                                       target:self
                                                     selector:@selector(_doBoredEvent)
                                                     userInfo:nil
                                                      repeats:NO];
}

//------------------------------------------------------------------------------
- (void)deactivateMotionDetection
{
    if (_motionDetectionModule) {
        [self.motionDetectionModule.vision deactivateModule:self.motionDetectionModule];
        self.motionDetectionModule = nil;
    }
}

//------------------------------------------------------------------------------
- (void)_scheduleCuriosityTimers
{
    [self.boredTimer invalidate];
    [self.sleepTimer invalidate];
    [self deactivateMotionDetection];
    self.boredTimer = [NSTimer scheduledTimerWithTimeInterval:kBoredTimeout
                                                       target:self
                                                     selector:@selector(_doBoredEvent)
                                                     userInfo:nil
                                                      repeats:NO];
    
    self.sleepTimer = [NSTimer scheduledTimerWithTimeInterval:kSleepTimeout
                                                       target:self
                                                     selector:@selector(_sleepEventTriggered)
                                                     userInfo:nil
                                                      repeats:NO];
}

//------------------------------------------------------------------------------
- (void)_sleepEventTriggered
{
    [self.sleepTimer invalidate];
    [self.boredTimer invalidate];
    [self deactivateMotionDetection];

    [self.motivationManager activateMotivation:RMMotivation_Sleep];
    if (!self.sleepy) {
        [self.Romo.character setExpression:RMCharacterExpressionSleepy
                               withEmotion:RMCharacterEmotionSleepy];
        
        // Reschedule so we go to sleep
        self.sleepTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                           target:self
                                                         selector:@selector(_sleepEventTriggered)
                                                         userInfo:nil
                                                          repeats:NO];
    } else {
        self.motivationManager.motivation = RMMotivation_Sleep;
    }
    self.sleepy = !self.sleepy;
}

//------------------------------------------------------------------------------
- (void)robotDidDetectPickup
{
    [self.robot stopAllMotion];
    [super robotDidDetectPickup];
    [self.tracker resetTracker];
}

#pragma mark - Private Properties
//------------------------------------------------------------------------------
- (RMTracker *)tracker
{
    if (!_tracker) {
        _tracker = [[RMTracker alloc] init];
    }
    return _tracker;
}

//------------------------------------------------------------------------------
- (RMMotionDetectionModule *)motionDetectionModule
{
    if (!_motionDetectionModule) {
        _motionDetectionModule = [[RMMotionDetectionModule alloc] initWithVision:self.Romo.vision];
        _motionDetectionModule.delegate = self;
        _motionDetectionModule.minimumPercentageOfPixelsMoving = motionDetectionPercentOfPixelsMovingThreshold;
        _motionDetectionModule.minimumConsecutiveTriggerCount = motionDetectionConsecutiveTriggerCount;
    }
    return _motionDetectionModule;
}

#pragma mark - Private Methods

- (void)requestPhotoLibraryPermission
{
    // By creating and showing a UIImagePickerController, the user will be
    // prompted to allow photo access
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    picker.view.frame = CGRectZero;
    picker.view.clipsToBounds = YES;
    picker.view.alpha = 0.0;
    [self.view addSubview:picker.view];
    [picker.view removeFromSuperview];
}

@end
