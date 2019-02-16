//
//  RMTrainingRuntimeRobotController.m
//  Romo
//

#import "RMRuntimeRobotController.h"
#import <Romo/RMVision.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIButton+RMButtons.h"
#import "RMMissionRobotController.h"
#import "RMAppDelegate.h"
#import "RMAPI.h"
#import "RMMission.h"
#import "RMEvent.h"
#import "RMParameter.h"
#import "RMAction.h"

@interface RMRuntimeRobotController () <RMMissionDelegate, RMVisionDelegate>

@property (nonatomic, strong) RMEvent *event;

/** Used for delaying the start and finish of runtime */
@property (nonatomic, strong) NSTimer *runtimeDelayTimer;

@property (nonatomic, strong) NSTimer *timeEventTimer;


@end

@implementation RMRuntimeRobotController

#pragma mark - View Lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        self.allowsBroadcastingWhenActive = NO;
    }
    return self;
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];

    self.Romo.character.emotion = RMCharacterEmotionHappy;

    self.mission.API.Romo = self.Romo;

    self.runtimeDelayTimer = [NSTimer scheduledTimerWithTimeInterval:0.75 target:self selector:@selector(startRunning) userInfo:nil repeats:NO];
}

- (void)controllerDidResignActive
{
    [super controllerDidResignActive];
    
    self.mission.API.Romo = nil;
    [self.mission.API stopAllActions];

    [self.runtimeDelayTimer invalidate];
    [self.timeEventTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)startRunning
{
    self.mission.running = YES;
    
    for (RMEvent *event in self.mission.events) {
        if (event.type == RMEventMissionStart) {
            NSDictionary *eventInfo = @{ @"type" : @(event.type) };
            [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
            break;
        }
    }
 
    self.timeEventTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(generateTimeEvent) userInfo:nil repeats:YES];
}

#pragma mark - Public Properties

- (void)setMission:(RMMission *)mission
{
    _mission = mission;
    mission.delegate = self;
    mission.API.Romo = self.Romo;
}

#pragma mark -- Private Methods

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    [self.delegate runtimeDisconnectedFromRobot:self];
}

#pragma mark - RMMissionDelegate

- (void)mission:(RMMission *)mission eventDidOccur:(RMEvent *)event
{
    self.event = event;
}

- (void)mission:(RMMission *)mission scriptForEventDidFinish:(RMEvent *)event
{
}

- (void)mission:(RMMission *)mission beganRunningAction:(RMAction *)action
{
}

- (void)mission:(RMMission *)mission finishedRunningAction:(RMAction *)action
{
}

- (void)missionFinishedRunningAllScripts:(RMMission *)mission
{
    [self.delegate runtimeFinishedRunningAllScripts:self];
}

#pragma mark - RMVisionDelegate

- (void)didDetectFace:(RMFace *)face
{
    if (face.justFound) {
        NSDictionary *eventInfo = @{ @"type" : @(RMEventFace), @"parameter" : @"appear" };
        [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
    }
}

- (void)didLoseFace
{
    NSDictionary *eventInfo = @{ @"type" : @(RMEventFace), @"parameter" : @"disappear" };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
}

#pragma mark - RMTouchDelegate

- (void)touch:(RMTouch *)touch beganPokingAtLocation:(RMTouchLocation)location
{
    NSDictionary *pokeAnywhereEvent = @{ @"type" : @(RMEventPokeAnywhere) };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:pokeAnywhereEvent];

    NSString *locationName = [RMTouch nameForLocation:location];
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
    if (orientation != RMRobotOrientationUpright) {
        [self.delegate runtime:self robotDidFlipToOrientation:orientation];
    }
}

- (void)robotDidDetectShake
{
    NSDictionary *eventInfo = @{ @"type" : @(RMEventShake) };
    [[NSNotificationCenter defaultCenter] postNotificationName:RMEventDidOccurNotification object:self userInfo:eventInfo];
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

@end
