//
//  RMTrainingRuntimeRobotController.m
//  Romo
//

#import "RMRuntimeRobotController.h"
#import <Romo/RMVision.h>
#import <Romo/RMBrightnessMeteringModule.h>
#import <Romo/RMMotionDetectionModule.h>
#import <Romo/RMVisionBrightHueSegmentationModule.h>
#import <Romo/RMMath.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIButton+RMButtons.h"
#import "RMMissionRobotController.h"
#import "RMAppDelegate.h"
#import "RMActionRuntime.h"
#import "RMMission.h"
#import "RMEvent.h"
#import "RMParameter.h"
#import "RMAction.h"
#import "RMFavoriteColorRobotController.h"
#import "RMRomoMemory.h"
#import "RMStasisVirtualSensor.h"
#import "RMSoundEffect.h"

static const float motionDetectionTriggerTimeout = 4.0; // seconds
static const float motionDetectionPercentOfPixelsMovingThreshold = 2.5; // percent
static const int motionDetectionConsecutiveTriggerCount = 3; // # of frames

static const float loudSoundTriggerTimeout = 4.0; // seconds

@interface RMRuntimeRobotController () <RMMissionDelegate, RMBrightnessMeteringModuleDelegate, RMMotionDetectionModuleDelegate, RMVisionBrightHueSegmentationModuleDelegate, RMStasisVirtualSensorDelegate>

@property (nonatomic, strong) RMEvent *event;

/** Used for delaying the start and finish of runtime */
@property (nonatomic, strong) NSTimer *runtimeDelayTimer;

@property (nonatomic, strong) NSTimer *timeEventTimer;

/** If the mission is time-based, this timer fires when the mission times out */
@property (nonatomic, strong) NSTimer *timeoutTimer;

@property (nonatomic) BOOL allowsUndocking;

/** A list of events that have not been triggered in the current run of the mission */
@property (nonatomic, strong) NSMutableArray *remainingEvents;

/** A lazy loaded (from UntriggeredEventPrompts.json) collection of event names to messages */
@property (nonatomic, strong) NSDictionary *eventPrompts;

@property (nonatomic, strong) RMBrightnessMeteringModule *brightnessMeteringModule;
@property (nonatomic, strong) RMMotionDetectionModule *motionDetectionModule;
@property (nonatomic, strong) RMVisionBrightHueSegmentationModule *hueDetectionModule;
@property (nonatomic, strong) RMStasisVirtualSensor *stasisVirtualSensor;

/** Played for time-based missions */
@property (nonatomic, strong) RMSoundEffect *timeJingle;

/** A simple display of time remaining */
@property (nonatomic, strong) UIView *timeBar;

@property (nonatomic) double timeOfLastMotionDetection;
@property (nonatomic) double timeOfLastLoudSound;

@end

// The delay after an event triggers for Romo to prompt about other events
static const CGFloat UNTRIGGERED_EVENT_PROMPT_DELAY = 10.0;

// The delay Romo waits to prompt about an event after just doing so
static const CGFloat UNTRIGGERED_EVENT_PROMPT_REPEAT_DELAY = 4.0;

@implementation RMRuntimeRobotController

@dynamic delegate;

#pragma mark - View Lifecycle

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    self.Romo.character.emotion = RMCharacterEmotionHappy;
    self.mission.actionRuntime.Romo = self.Romo;
    
    self.remainingEvents = [self.mission.events mutableCopy];
    
    if (self.mission.lightInitiallyOff) {
        [self.Romo.robot.LEDs turnOff];
    }
    
    if (self.mission.duration <= 0) {
        // If the mission isn't time-based, start after a short delay
        self.runtimeDelayTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(startRunning) userInfo:nil repeats:NO];
    } else {
        // Otherwise, play a countdown sounf effect then start
        [RMSoundEffect playForegroundEffectWithName:threeTwoOneCountdownSound repeats:NO gain:1.0];
        self.runtimeDelayTimer = [NSTimer scheduledTimerWithTimeInterval:2.5 target:self selector:@selector(startRunning) userInfo:nil repeats:NO];
    }
    [self performSelector:@selector(promptRandomUntriggeredEvent) withObject:nil afterDelay:UNTRIGGERED_EVENT_PROMPT_DELAY];
}

- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    
    self.mission.actionRuntime.Romo = nil;
    [self.mission.actionRuntime stopAllActions];
    
    if (_stasisVirtualSensor) {
        [self.stasisVirtualSensor finishGeneratingStasisNotifications];
    }
    
    [self.Romo.vision deactivateAllModules];
    [self.Romo.robot.LEDs setSolidWithBrightness:1.0];
    [self.Romo.character setFillColor:nil percentage:0.0];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(promptRandomUntriggeredEvent) object:nil];
    
    [self.runtimeDelayTimer invalidate];
    [self.timeEventTimer invalidate];
    [self.timeoutTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_timeJingle) {
        [self.timeJingle pause];
        self.timeJingle = nil;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - RMRobotController Overrides

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    return RMRomoFunctionalityCharacter;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    return RMRomoInterruptionRomotion | RMRomoInterruptionSelfRighting;
}

#pragma mark - RMCometRobotController Overrides

- (NSString *)title
{
    if (self.mission.chapter == RMChapterTheLab) {
        return NSLocalizedString(@"Lab-Mission-Title", @"The Lab");
    } else {
        return [NSString stringWithFormat:NSLocalizedString(@"Generic-Mission-Title", @"Mission %d-%d"), self.mission.chapter, self.mission.index];
    }
}

- (RMChapter)chapter
{
    return self.mission.chapter;
}

- (BOOL)showsHelpButton
{
    return NO;
}

#pragma mark - Private Methods

- (void)startRunning
{
    if (self.Romo.robot) {
        self.mission.running = YES;
        [self activateNecessaryFunctionalities];
        
        // Before we run, clear out any other photos so we only have photos stored from this mission
        [[RMProgressManager sharedInstance].capturedPhotos removeAllObjects];
        
        for (RMEvent *event in self.mission.events) {
            if (event.type == RMEventMissionStart) {
                NSDictionary *eventInfo = @{ @"type" : @(event.type) };
                [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
                break;
            }
        }

        if (self.allowsUndocking) {
            // End if backgrounded on missions that don't end when undocked
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleApplicationDidEnterBackgroundNotification:)
                                                         name:UIApplicationDidEnterBackgroundNotification
                                                       object:nil];
        }
        
        self.timeEventTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(generateTimeEvent) userInfo:nil repeats:YES];
        
        if (self.mission.duration > 0) {
            // If time based, fire a timeout timer
            self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:self.mission.duration
                                                                 target:self
                                                               selector:@selector(handleMissionTimeoutTimer:)
                                                               userInfo:nil
                                                                repeats:NO];
            
            // and start the jingle
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                [self.timeJingle play];
            });
            
            self.timeBar.bottom = self.view.height;
            self.timeBar.width = self.view.width;
            [self.view addSubview:self.timeBar];
            [UIView animateWithDuration:self.mission.duration delay:0.0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                                 self.timeBar.width = 0.0;
                             } completion:^(BOOL finished) {
                                 [self.timeBar removeFromSuperview];
                                 self.timeBar = nil;
                             }];
        }
    } else {
        [self robotDidDisconnect:nil];
    }
}

#pragma mark - Public Properties

- (void)setMission:(RMMission *)mission
{
    _mission = mission;
    mission.delegate = self;
    mission.actionRuntime.Romo = self.Romo;
}

#pragma mark -- Private Methods

- (void)handleApplicationDidEnterBackgroundNotification:(NSNotification *)notification
{
    [self.delegate runtimeDidEnterBackground:self];
}

- (void)robotDidConnect:(RMCoreRobot *)robot
{
    if (self.allowsUndocking) {
        NSDictionary *eventInfo = @{ @"type" : @(RMEventDock) };
        [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (self.allowsUndocking) {
        NSDictionary *eventInfo = @{ @"type" : @(RMEventUndock) };
        [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
    } else {
        [self.delegate runtimeDisconnectedFromRobot:self];
    }
}

- (void)activateNecessaryFunctionalities
{
    // Right now, we only check for events that use equilibrioception
    __block BOOL usesEquilibrioception = NO;
    __block BOOL usesLoudSound = NO;
    [self.mission.events enumerateObjectsUsingBlock:^(RMEvent *event, NSUInteger idx, BOOL *stop) {
        usesEquilibrioception |= (event.type == RMEventShake || event.type == RMEventPutDown || event.type == RMEventPickedUp) || event.type == RMEventStasis;
        usesLoudSound |= event.type == RMEventHearsLoudSound;
    }];
    
    __block BOOL usesVision = NO;
    __block BOOL usesStasis = YES;
    [self.mission.inputScripts enumerateObjectsUsingBlock:^(NSArray *script, NSUInteger idx, BOOL *stop) {
        [script enumerateObjectsUsingBlock:^(RMAction *action, NSUInteger idx, BOOL *stop) {
            if ([action.library isEqualToString:@"Camera"]) {
                usesVision = YES;
            } else if ([action.title isEqualToString:@"Start Exploring"]) {
                usesVision = YES;
                usesStasis = YES;
                usesEquilibrioception = YES;
            }
        }];
    }];
    
    if (usesEquilibrioception) {
        self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityEquilibrioception, self.Romo.activeFunctionalities);
    } else {
        self.Romo.activeFunctionalities = disableFunctionality(RMRomoFunctionalityEquilibrioception, self.Romo.activeFunctionalities);
    }
    
    if (usesLoudSound) {
        self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityLoudSound, self.Romo.activeFunctionalities);
    } else {
        self.Romo.activeFunctionalities = disableFunctionality(RMRomoFunctionalityLoudSound, self.Romo.activeFunctionalities);
    }
    
    if (self.mission.visionModules.count || usesVision) {
        // If any events use vision, activate Romo's vision plus any relevant modules
        self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
        
        if (usesStasis) {
            [self.stasisVirtualSensor beginGeneratingStasisNotifications];
        }
        
        [self.mission.visionModules enumerateObjectsUsingBlock:^(NSString *moduleKey, BOOL *stop) {
            if ([moduleKey isEqualToString:@"RMVisionModule_BrightnessMetering"]) {
                [self.Romo.vision activateModule:self.brightnessMeteringModule];
            } else if ([moduleKey isEqualToString:@"RMVisionModule_MotionDetection"]) {
                [self.Romo.vision activateModule:self.motionDetectionModule];
            } else if ([moduleKey isEqualToString:@"RMVisionModule_HueDetection"]) {
                [self.Romo.vision activateModule:self.hueDetectionModule];
            } else if ([moduleKey isEqualToString:@"RMVisionModule_StasisDetection"]) {
                [self.stasisVirtualSensor beginGeneratingStasisNotifications];
            } else {
                [self.Romo.vision activateModuleWithName:moduleKey];
            }
        }];
        
        self.mission.actionRuntime.vision = self.Romo.vision;
    }
}

#pragma mark - Timeout

- (void)handleMissionTimeoutTimer:(NSTimer *)timer
{
    [self.delegate runtimeDidTimeout:self];
}

#pragma mark - Prompting to do events

- (void)promptRandomUntriggeredEvent
{
    if (self.remainingEvents.count) {
        // Randomly select an untriggered event
        NSUInteger randomIndex = arc4random() % self.remainingEvents.count;
        RMEvent *event = [self.remainingEvents objectAtIndex:randomIndex];
        
        NSString *key = [RMEvent nameForEventType:event.type];
        
        if ([event.parameter.value isKindOfClass:[NSString class]]) {
            key = [key stringByAppendingFormat:@":%@", event.parameter.value];
        }
        
        NSArray *eventMessages = [self.eventPrompts valueForKey:key];
        
        // If this event has messages defined, show a random message
        if (eventMessages.count) {
            randomIndex = arc4random() % eventMessages.count;
            
            // When event is dock and robot is already docked
            BOOL dockWhenAlreadyDocked = event.type == RMEventDock && self.Romo.robot;
            
            // When the lights are [off/on] and the event is [off/on]
            BOOL lightsAreOn = self.brightnessMeteringModule.brightnessState == RMVisionBrightnessStateBright ||
            self.brightnessMeteringModule.brightnessState == RMVisionBrightnessStateTooBright ||
            self.brightnessMeteringModule.brightnessState == RMVisionBrightnessStateUnknown;
            BOOL lightsOffWhenAlreadyOff = event.type == RMEventLightsOff && !lightsAreOn;
            BOOL lightsOnWhenAlreadyOn = event.type == RMEventLightsOn && lightsAreOn;
            
            // Only prompt if the prompt makes sense
            BOOL shouldPromptForThisEvent = !dockWhenAlreadyDocked && !lightsOffWhenAlreadyOff && !lightsOnWhenAlreadyOn;
            if (shouldPromptForThisEvent) {
                [self.Romo.voice say:[eventMessages objectAtIndex:randomIndex] withStyle:RMVoiceStyleSSS autoDismiss:YES];
            }
        }
        
        // Requeue the prompt, but wait a bit longer
        [self performSelector:@selector(promptRandomUntriggeredEvent) withObject:nil afterDelay:UNTRIGGERED_EVENT_PROMPT_REPEAT_DELAY];
    }
}

#pragma mark - Event prompt messages

- (NSDictionary *)eventPrompts
{
    if (!_eventPrompts) {
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"UntriggeredEventPrompts" ofType:@"json"];
        NSData *rawJSONData = [NSData dataWithContentsOfFile:filePath];
        _eventPrompts = [NSJSONSerialization JSONObjectWithData:rawJSONData options:0 error:nil];
    }
    
    return _eventPrompts;
}

#pragma mark - RMMissionDelegate

- (void)mission:(RMMission *)mission eventDidOccur:(RMEvent *)event
{
    self.event = event;
    
    [self.remainingEvents removeObject:event];
    
    // Clear the pending event prompt request
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(promptRandomUntriggeredEvent) object:nil];
}

- (void)mission:(RMMission *)mission scriptForEventDidFinish:(RMEvent *)event
{
    // Reset the pending event prompt request
    [self performSelector:@selector(promptRandomUntriggeredEvent) withObject:nil afterDelay:UNTRIGGERED_EVENT_PROMPT_DELAY];
}

- (void)missionFinishedRunningAllScripts:(RMMission *)mission
{
    [self.delegate runtimeFinishedRunningAllScripts:self];
}

#pragma mark - RMVisionDelegate

- (void)didDetectFace:(RMFace *)face
{
    if (face.justFound) {
        NSDictionary *eventInfo = @{ @"type" : @(RMEventFaceAppear) };
        [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
    }
}

- (void)didLoseFace
{
    NSDictionary *eventInfo = @{ @"type" : @(RMEventFaceDisappear) };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
}

#pragma mark - RMTouchDelegate

- (void)touch:(RMTouch *)touch beganPokingAtLocation:(RMTouchLocation)location
{
    NSDictionary *pokeAnywhereEvent = @{ @"type" : @(RMEventPokeAnywhere) };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:pokeAnywhereEvent];
    
    NSString *locationName = [RMTouch nameForLocation:location];
    if ([locationName isEqualToString:@"left eye"] || [locationName isEqualToString:@"right eye"]) {
        locationName = @"eye";
    }
    NSDictionary *eventInfo = @{ @"type" : @(RMEventPoke), @"parameter" : locationName };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
}

- (void)touch:(RMTouch *)touch detectedTickleAtLocation:(RMTouchLocation)location
{
    if (location != RMTouchLocationLeftEye && location != RMTouchLocationRightEye) {
        NSString *locationName = [RMTouch nameForLocation:location];
        NSDictionary *eventInfo = @{ @"type" : @(RMEventTickle), @"parameter" : locationName };
        [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
    }
}

#pragma mark - RMEquilibrioceptionDelegate

- (void)robotDidDetectPickup
{
    NSDictionary *eventInfo = @{ @"type" : @(RMEventPickedUp) };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
}

- (void)robotDidDetectPutDown
{
    NSDictionary *eventInfo = @{ @"type" : @(RMEventPutDown) };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
}

- (void)robotDidFlipToOrientation:(RMRobotOrientation)orientation
{
    if (!self.mission.disableFlipDetection) {
        if (orientation != RMRobotOrientationUpright) {
            [self.delegate runtime:self robotDidFlipToOrientation:orientation];
        }
    }
}

- (void)robotDidDetectShake
{
    NSDictionary *eventInfo = @{ @"type" : @(RMEventShake) };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
}

- (void)robotDidStartClimbing
{
    NSDictionary *eventInfo = @{ @"type" : @(RMEventStasis) };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
}

#pragma mark - RMLoudSoundDetectorDelegate

- (void)loudSoundDetectorDetectedLoudSound:(RMLoudSoundDetector *)loudSoundDetector
{
    if (!self.Romo.robot.isDriving && !self.Romo.robot.isTilting && currentTime() - self.timeOfLastLoudSound >= loudSoundTriggerTimeout) {
        self.timeOfLastLoudSound = currentTime();
        NSDictionary *eventInfo = @{ @"type" : @(RMEventHearsLoudSound) };
        [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
    }
}

#pragma mark - RMBrightnessMeteringModuleDelegate

- (void)brightnessMeteringModule:(RMBrightnessMeteringModule *)module didDetectBrightnessChangeFromState:(RMVisionBrightnessState)previousState toState:(RMVisionBrightnessState)brightnessState
{
    // Only trigger events if the lights changed from on to off (or off to on)
    if (previousState != RMVisionBrightnessStateUnknown) {
        RMEventType eventType = 0;
        switch (brightnessState) {
            case RMVisionBrightnessStateBright:
            case RMVisionBrightnessStateTooBright:
                if (previousState != RMVisionBrightnessStateTooBright && previousState != RMVisionBrightnessStateBright) {
                    eventType = RMEventLightsOn;
                }
                break;
                
            case RMVisionBrightnessStateDark:
            case RMVisionBrightnessStateTooDark:
                if (previousState != RMVisionBrightnessStateTooDark && previousState != RMVisionBrightnessStateDark) {
                    eventType = RMEventLightsOff;
                }
                break;
                
            default:
                break;
        }
        
        if (eventType) {
            NSDictionary *eventInfo = @{ @"type" : @(eventType) };
            [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
        }
    }
}

#pragma mark - RMMotionDetectionModuleDelegate

- (void)motionDetectionModuleDidDetectMotion:(RMMotionDetectionModule *)module
{
    if (currentTime() - self.timeOfLastMotionDetection >= motionDetectionTriggerTimeout && !self.Romo.robot.isDriving && !self.Romo.robot.isTilting) {
        self.timeOfLastMotionDetection = currentTime();
        NSDictionary *eventInfo = @{ @"type" : @(RMEventSeesMotion) };
        [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
    }
}

- (void)motionDetectionModuleDidDetectEndOfMotion:(RMMotionDetectionModule *)module
{
    // stub
}

#pragma mark - RMVisionBrightHueSegmentationModuleDelegate

- (void)hueSegmentationModuleDidDetectHue:(RMVisionBrightHueSegmentationModule *)module
{
    NSDictionary *eventInfo = @{ @"type" : @(RMEventFavoriteColor) };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
}

#pragma mark - RMStasisVirtualSensorDelegate

- (void)virtualSensorDidDetectStasis:(RMStasisVirtualSensor *)stasisVirtualSensor
{
    NSDictionary *eventInfo = @{ @"type" : @(RMEventStasis) };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
}

- (void)virtualSensorDidLoseStasis:(RMStasisVirtualSensor *)stasisVirtualSensor
{
    // Ignore these
}

#pragma mark - Private Methods

/**
 Posts a new event notification every minute with the current time
 */
- (void)generateTimeEvent
{
    static NSString *previousSentTime = nil;
    static NSDateFormatter *dateFormat = nil;
    
    if (!dateFormat) {
        dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"hh:mm a"];
    }
    
    NSString *time = [dateFormat stringFromDate:[NSDate date]];
    if ([time characterAtIndex:0] == '0' && [time characterAtIndex:1] != ':') {
        time = [time substringFromIndex:1];
    }
    
    if (![time isEqualToString:previousSentTime]) {
        NSDictionary *eventInfo = @{ @"type" : @(RMEventTime), @"parameter" : time };
        [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:nil userInfo:eventInfo];
        previousSentTime = time;
    }
}

- (BOOL)allowsUndocking
{
    if (self.chapter == RMChapterTheLab) {
        return YES;
    }
    
    for (RMEvent *event in self.mission.events) {
        if (event.type == RMEventUndock || event.type == RMEventDock) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Private Properties

- (RMBrightnessMeteringModule *)brightnessMeteringModule
{
    if (!_brightnessMeteringModule) {
        _brightnessMeteringModule = [[RMBrightnessMeteringModule alloc] initWithVision:self.Romo.vision];
        _brightnessMeteringModule.delegate = self;
    }
    return _brightnessMeteringModule;
}

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

- (RMVisionBrightHueSegmentationModule *)hueDetectionModule
{
    if (!_hueDetectionModule) {
        _hueDetectionModule = [[RMVisionBrightHueSegmentationModule alloc] initWithVision:self.Romo.vision];
        _hueDetectionModule.delegate = self;
        
        // We want to be more sensitive to colors, so we increase the bounds by this factor and allow more colors through
        static const float increasedHueWidthFactor = 1.5;
        static const float hueFractionThreshold = 0.10;
        static const float saturationThreshold = 0.45;
        static const float brightnessThreshold = 0.55;
        float favoriteHue = [[RMRomoMemory sharedInstance] knowledgeForKey:favoriteColorKnowledgeKey].floatValue;
        _hueDetectionModule.hueLeftBound = favoriteHue - (favoriteHueWidth / 2.0) * increasedHueWidthFactor;
        _hueDetectionModule.hueRightBound = favoriteHue + (favoriteHueWidth / 2.0) * increasedHueWidthFactor;
        _hueDetectionModule.hueFractionThreshold = hueFractionThreshold;
        _hueDetectionModule.saturationThreshold = saturationThreshold;
        _hueDetectionModule.brightnessThreshold = brightnessThreshold;
    }
    return _hueDetectionModule;
}

- (RMStasisVirtualSensor *)stasisVirtualSensor
{
    if (!_stasisVirtualSensor) {
        _stasisVirtualSensor = [[RMStasisVirtualSensor alloc] init];
        _stasisVirtualSensor.delegate = self;
        _stasisVirtualSensor.Romo = self.Romo;
        self.mission.actionRuntime.stasisVirtualSensor = _stasisVirtualSensor;
    }
    return _stasisVirtualSensor;
}

- (RMSoundEffect *)timeJingle
{
    if (!_timeJingle) {
        _timeJingle = [[RMSoundEffect alloc] initWithName:@"musicMission"];
        _timeJingle.repeats = YES;
    }
    return _timeJingle;
}

- (UIView *)timeBar
{
    if (!_timeBar) {
        _timeBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 12.0)];
        _timeBar.backgroundColor = [UIColor whiteColor];
        _timeBar.userInteractionEnabled = NO;
    }
    return _timeBar;
}

@end
