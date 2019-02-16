//
//  RMTelepresenceHostRobotController.m
//  Romo
//
//  Created on 11/5/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMTelepresenceHostRobotController.h"
#import "RMTelepresence.h"
#import "RMOpenTokManager.h"
#import <Opentok/Opentok.h>
#import <Romo/RMDispatchTimer.h>
#import "UIAlertView+RMDismissAll.h"
#import "RMAnalytics.h"

@interface RMTelepresenceHostRobotController () <RMOpenTokManagerDelegate>

@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, copy) RMTelepresence2HostRobotControllerCompletion completion;
@property (nonatomic, copy) void(^endSessionCompletionHandler)();

// Views
@property (nonatomic, strong) UIButton *endCallButton;
@property (nonatomic, strong) UIButton *muteMicButton;
@property (nonatomic, strong) UIButton *muteSpeakerButton;

// OpenTok
@property (nonatomic, strong) RMOpenTokManager *otManager;

// Watchdog
@property (nonatomic, strong) RMDispatchTimer *watchdogTimer;
@property (nonatomic, assign) CFTimeInterval lastDriveCommandInterval;

// Gates
@property (nonatomic, assign) RMTelepresenceDriveCommand previousDriveCommand;
@property (nonatomic, assign, getter = isMicMuted) BOOL micMuted;
@property (nonatomic, assign, getter = isTurning) BOOL turning;
@property (nonatomic, assign, getter = isDriving) BOOL driving;
@property (nonatomic, assign, getter = isExpressing) BOOL expressing;

@end

@implementation RMTelepresenceHostRobotController

- (instancetype)initWithUUID:(NSString *)uuid
                   sessionID:(NSString *)otSessionID
                            token:(NSString *)otToken
                       completion:(RMTelepresence2HostRobotControllerCompletion)completion
{
    self = [super init];
    if (self) {
        _uuid = uuid;
        _completion = completion;
        
        _otManager = [[RMOpenTokManager alloc] initWithUUID:uuid sessionID:otSessionID token:otToken];
        _otManager.delegate = self;
    }
    return self;
}

- (void)dealloc
{
    DDLogVerbose(@"");
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    return RMRomoFunctionalityEquilibrioception;
}

- (NSSet *)initiallyActiveVisionModules
{
    return [NSSet set];
}

- (void)viewDidLoad
{
    [super viewDidLoad];    
    
    self.endCallButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.endCallButton.frame = CGRectMake(255, 20, 45, 45);
    self.endCallButton.enabled = NO;
    [self.endCallButton setImage:[UIImage imageNamed:@"menuBarDisconnect"] forState:UIControlStateNormal];
    [self.endCallButton addTarget:self action:@selector(handleEndCallPress:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.endCallButton];
    
    // To get around an OpenTok edge case crash, we will re-enable the end call button either when the
    // session connects, or 5 seconds has elapsed. The crash is a known OT bug when a session that is
    // being created is promptly ended. They state it will be resolved in 2.1.7 (as of Oct 28, 2013)
    double delayInSeconds = 5.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        self.endCallButton.enabled = YES;
    });
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    [self.otManager connect];
    
    [self.otManager addTarget:self action:@selector(didReceiveDriveSignal:) forSignal:@"drive"];
    [self.otManager addTarget:self action:@selector(didReceiveTurnByAngleSignal:) forSignal:@"turnByAngle"];
    [self.otManager addTarget:self action:@selector(didReceiveTiltToAngleSignal:) forSignal:@"tiltToAngle"];
    [self.otManager addTarget:self action:@selector(didReceiveExpressionSignal:) forSignal:@"expression"];
    [self.otManager addTarget:self action:@selector(didReceiveModeSignal:) forSignal:@"mode"];
    
    [self startWatchdogTimer];
}

- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    [UIAlertView dismissAll];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void)startWatchdogTimer
{
    __weak RMTelepresenceHostRobotController *wself = self;
    
    self.watchdogTimer = [[RMDispatchTimer alloc] initWithQueue:dispatch_get_main_queue() frequency:1];
    self.watchdogTimer.eventHandler = ^ {
        // If it has been 3 seconds since the last drive command, stop driving.
        // This prevents run away robots.
        if (CACurrentMediaTime() - wself.lastDriveCommandInterval > 3) {
            [wself.Romo.robot stopDriving];
        }
    };
    [self.watchdogTimer startRunning];
}

- (void)endSessionWithCompletion:(void(^)())completion
{
    self.endSessionCompletionHandler = completion;
    [self.otManager disconnect];
}

#pragma mark - OpenTok Signals

- (void)didReceiveDriveSignal:(id)data
{
    RMTelepresenceDriveCommand command = [data integerValue];
    DDLogVerbose(@"[%@] Got drive command: %d", self.uuid, command);
    
    if (self.isTurning || !self.Romo.RomoCanDrive) {
        return;
    }
    
    self.lastDriveCommandInterval = CACurrentMediaTime();
    
    if (self.previousDriveCommand == command) {
        return;
    }
    
    self.previousDriveCommand = command;
    self.driving = YES;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(unmuteAfterDrive) object:nil];

    switch (command) {
        case RMTelepresenceDriveCommandForward:
            self.otManager.otPublisher.publishAudio = NO;
            [self.Romo.robot driveForwardWithSpeed:0.7];
            break;

        case RMTelepresenceDriveCommandBackward:
            self.otManager.otPublisher.publishAudio = NO;
            [self.Romo.robot driveBackwardWithSpeed:0.7];
            break;
            
        case RMTelepresenceDriveCommandLeft:
            [(RMCoreRobot<DriveProtocol> *)self.Romo.robot driveWithRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                                                                     speed:0.2];
            break;
            
        case RMTelepresenceDriveCommandRight:
            [(RMCoreRobot<DriveProtocol> *)self.Romo.robot driveWithRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                                                                     speed:-0.2];
            break;

        default:
            [self performSelector:@selector(unmuteAfterDrive) withObject:nil afterDelay:0.25];
            [self.Romo.robot stopDriving];
            self.driving = NO;
            break;
    }
}

- (void)unmuteAfterDrive
{
    self.otManager.otPublisher.publishAudio = !self.isMicMuted;
}

- (void)didReceiveTurnByAngleSignal:(id)data
{
    CGFloat angle = [data floatValue];
    DDLogVerbose(@"[%@] Got turnByAngle command: %f", self.uuid, angle);
    
    if (self.isTurning) {
        return;
    }

    self.turning = YES;
    [self.Romo.robot turnByAngle:angle withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE completion:^(BOOL success, float heading) {
        self.turning = NO;
//        [self.otManager.otSession signalWithType:@"didTurnByAngle" data:@(success) completionHandler:^(NSError *error) {}];
    }];
}

- (void)didReceiveTiltToAngleSignal:(id)data
{
    CGFloat angle = [data floatValue];
    DDLogVerbose(@"[%@] Got tiltToAngle command: %f", self.uuid, angle);

    [self.Romo.robot tiltToAngle:angle completion:^(BOOL success) {
//        [self.otManager.otSession signalWithType:@"didTiltToAngle" data:@(success) completionHandler:^(NSError *error) {}];
    }];
}

- (void)didReceiveModeSignal:(id)data
{
    RMTelepresenceModeCommand mode = [data integerValue];
    DDLogVerbose(@"[%@] Got mode command: %d", self.uuid, mode);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (mode) {
            case RMTelepresenceModeCommandRomo:
                self.otManager.otSubscriber.subscribeToVideo = NO;
                self.Romo.activeFunctionalities = enableFunctionality(self.Romo.activeFunctionalities, RMRomoFunctionalityCharacter);
                
                self.muteMicButton.frame = CGRectMake(125, 20, 45, 45);
                self.muteSpeakerButton.frame = CGRectMake(190, 20, 45, 45);
                
                break;
                
            case RMTelepresenceModeCommandVideo:
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.otManager.otSubscriber.subscribeToVideo = YES;
                    self.Romo.activeFunctionalities = disableFunctionality(self.Romo.activeFunctionalities, RMRomoFunctionalityCharacter);
                    
                    self.muteMicButton.frame = CGRectMake(255, 85, 45, 45);
                    self.muteSpeakerButton.frame = CGRectMake(255, 150, 45, 45);
                });
                
                break;
        }
        
        [self.view bringSubviewToFront:self.endCallButton];
        [self.view bringSubviewToFront:self.muteMicButton];
        [self.view bringSubviewToFront:self.muteSpeakerButton];
    });
}

- (void)didReceiveExpressionSignal:(id)data
{
    RMCharacterExpression expression = [data integerValue];
    DDLogVerbose(@"[%@] Got expression command: %d", self.uuid, expression);
    
    if (self.isExpressing) {
        return;
    }
    
    if (isFunctionalityActive(RMRomoFunctionalityCharacter, self.Romo.activeFunctionalities)) {
        self.Romo.character.expression = expression;
    }
}

#pragma mark - UI events

- (void)handleEndCallPress:(id)sender
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Host: End Call Press" properties:@{@"uuid": self.uuid}];
    
    [self.otManager disconnect];
}

- (void)handleMuteMicPress:(id)sender
{
    self.micMuted = !self.micMuted;
    self.otManager.otPublisher.publishAudio = !self.isMicMuted;
    
    if (self.otManager.otPublisher.publishAudio) {
        [sender setImage:[UIImage imageNamed:@"menuBarMuteOn"] forState:UIControlStateNormal];
    } else {
        [sender setImage:[UIImage imageNamed:@"menuBarMute"] forState:UIControlStateNormal];
    }
}

- (void)handleMuteSpeakerPress:(id)sender
{
    self.otManager.otSubscriber.subscribeToAudio = !self.otManager.otSubscriber.subscribeToAudio;
    
    if (self.otManager.otSubscriber.subscribeToAudio) {
        [sender setImage:[UIImage imageNamed:@"menuBarMuteThemOn"] forState:UIControlStateNormal];
    } else {
        [sender setImage:[UIImage imageNamed:@"menuBarMuteThem"] forState:UIControlStateNormal];
    }
}

#pragma mark - RMOpenTokDelegate

- (void)otSessionManager:(RMOpenTokManager *)manager didEncounterUnhandlableError:(NSError *)error
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Host: OTSession Error" properties:@{@"uuid": self.uuid}];
    
    if (self.completion) {
        self.completion(error);
        self.completion = nil;
    }
    
    if (self.endSessionCompletionHandler) {
        self.endSessionCompletionHandler();
        self.endSessionCompletionHandler = nil;
    }
}

- (void)otSessionManagerDidDisconnect:(RMOpenTokManager *)manager
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Host: OTSession Disconnected" properties:@{@"uuid": self.uuid}];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RMTelepresenceRobotControllerSessionDidEnd"
                                                        object:self
                                                      userInfo:nil];
    
    if (self.completion) {
        self.completion(nil);
        self.completion = nil;
    }
    
    if (self.endSessionCompletionHandler) {
        self.endSessionCompletionHandler();
        self.endSessionCompletionHandler = nil;
    }
}

- (void)otSessionManagerDidConnect:(RMOpenTokManager *)manager
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Host: OTSession Connected" properties:@{@"uuid": self.uuid}];
    
    // Add the video view
    [self.view addSubview:manager.otPublisher.view];
    [self.view sendSubviewToBack:manager.otPublisher.view];

    manager.otPublisher.view.frame = self.view.bounds;
    
    // Remove the toolbar
//    [manager.otPublisher.view.toolbarView removeFromSuperview];
    
    // Enable the end call button
    self.endCallButton.enabled = YES;
}

- (void)otSessionManager:(RMOpenTokManager *)manager subscriberDidConnect:(OTSubscriber *)subscriber
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Host: Subscriber Connected" properties:@{@"uuid": self.uuid}];
    
    manager.otPublisher.view.frame = CGRectMake(10, 10, 75, 120);
    manager.otPublisher.view.layer.borderColor = [UIColor blackColor].CGColor;
    manager.otPublisher.view.layer.borderWidth = 2.0;
    manager.otPublisher.view.layer.cornerRadius = 3.0;

    subscriber.view.frame = self.view.bounds;
//    [subscriber.view.toolbarView removeFromSuperview];

    [self.view addSubview:subscriber.view];
    [self.view sendSubviewToBack:subscriber.view];
    
    // Add the mute buttons
    // FIXME: do not put this here..
    self.muteMicButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.muteMicButton.frame = CGRectMake(255, 85, 45, 45);
    [self.muteMicButton setImage:[UIImage imageNamed:@"menuBarMuteOn"] forState:UIControlStateNormal];
    [self.muteMicButton addTarget:self action:@selector(handleMuteMicPress:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.muteMicButton];
    
    self.muteSpeakerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.muteSpeakerButton.frame = CGRectMake(255, 150, 45, 45);
    [self.muteSpeakerButton setImage:[UIImage imageNamed:@"menuBarMuteThemOn"] forState:UIControlStateNormal];
    [self.muteSpeakerButton addTarget:self action:@selector(handleMuteSpeakerPress:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.muteSpeakerButton];
    
    
    NSString *romoName = self.Romo.name.length ? self.Romo.name : @"Romo";
    
//    [self.otManager.otSession signalWithType:@"whoami" data:@{@"romoName": romoName} completionHandler:^(NSError *error) {}];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RMTelepresenceRobotControllerSessionDidStart"
                                                        object:self
                                                      userInfo:nil];
}

- (void)otSessionManager:(RMOpenTokManager *)manager didDecodeFirstVideoFrameFromSubscriber:(OTSubscriber *)subscriber
{
    [[RMAnalytics sharedInstance] track:@"Telepresence Host: Received First Frame" properties:@{@"uuid": self.uuid}];
}

#pragma mark - RMCharacterDelegate

- (void)characterDidFinishExpressing:(RMCharacter *)character
{
    self.expressing = NO;
//    [self.otManager.otSession signalWithType:@"didFinishExpression" data:nil completionHandler:^(NSError *error) {}];
}

@end
