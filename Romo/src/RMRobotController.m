//
//  RMRobotController.m
//  Romo
//

#import "RMRobotController.h"
#import <Romo/RMMath.h>

#ifdef DEBUG_ROBOT_CONTROLLER
#define LOG(...) DDLogWarn(__VA_ARGS__)
#else
#define LOG(...)
#endif //DEBUG_ROBOT_CONTROLLER

NSString *const RMRobotControllerDidBecomeActiveNotification = @"RMRobotControllerDidBecomeActiveNotification";
NSString *const RMRobotControllerDidResignActiveNotification = @"RMRobotControllerDidResignActiveNotification";

@interface RMRobotController ()

@property (nonatomic, readwrite, getter=isActive) BOOL active;

@end

@implementation RMRobotController

#pragma mark - View Lifecycle

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Properties

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    // By default, we show the character and run equilibrioception
    return RMRomoFunctionalityCharacter | RMRomoFunctionalityEquilibrioception;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    // By default, we allow Romotions, self-righting, wakefulness emotions, and dizzy expressions
    return RMRomoInterruptionRomotion | RMRomoInterruptionSelfRighting | RMRomoInterruptionWakefulness | RMRomoInterruptionDizzy;
}

- (NSSet *)initiallyActiveVisionModules
{
    // By default, we don't use vision
    return nil;
}

#pragma mark - Controller Lifecycle

- (void)controllerWillBecomeActive
{
    LOG(@"self: %@", self);
    [UIApplication sharedApplication].statusBarHidden = YES;
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)controllerDidBecomeActive
{
    LOG(@"self: %@", self);
    self.active = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:RMRobotControllerDidBecomeActiveNotification
                                                        object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRobotDidConnectNotification:)
                                                 name:RMCoreRobotDidConnectNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRobotDidDisconnectNotification:)
                                                 name:RMCoreRobotDidDisconnectNotification
                                               object:nil];
    
    [self.Romo.character lookAtDefault];
    
    // name the top-level view so that testing scripts can tap it
    if (! (self.view.isAccessibilityElement
           && self.view.accessibilityLabel
           && self.view.accessibilityLabel.length > 0)) {
          self.view.accessibilityLabel = @"main view";
          self.view.isAccessibilityElement = YES;
          }
}

- (void)controllerWillResignActive
{
    LOG(@"self: %@", self);
    [self.Romo.romotions stopRomoting];
    [self.Romo.robot stopAllMotion];
}

- (void)controllerDidResignActive
{
    LOG(@"self: %@", self);
    self.active = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:RMRobotControllerDidResignActiveNotification
                                                        object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:RMCoreRobotDidConnectNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:RMCoreRobotDidDisconnectNotification
                                                  object:nil];
}

#pragma mark - RMRomoDelegate

- (UIView *)characterView
{
    return self.view;
}

#pragma mark - RMCharacterDelegate

- (void)characterDidBeginExpressing:(RMCharacter *)character
{
    // stub
}

- (void)characterDidFinishExpressing:(RMCharacter *)character
{
    // stub
}

#pragma mark - RMCoreDelegate

- (void)robotDidConnect:(RMCoreRobot *)robot
{
    // stub
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    // stub
}

#pragma mark - RMLoudSoundDetectorDelegate

- (void)loudSoundDetectorDetectedLoudSound:(RMLoudSoundDetector *)loudSoundDetector
{
    // stub
}

- (void)loudSoundDetectorDetectedEndOfLoudSound:(RMLoudSoundDetector *)loudSoundDetector
{
    // stub
}

#pragma mark - Private Methods

- (void)handleRobotDidConnectNotification:(NSNotification *)notification
{
    [self robotDidConnect:notification.object];
}

- (void)handleRobotDidDisconnectNotification:(NSNotification *)notification
{
    [self robotDidDisconnect:notification.object];
}

@end
