//
//  RUITelepresenceIncomingCallVC.m
//  Romo3
//
//  Created on 5/6/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMTelepresenceIncomingCallVC.h"
#import "RMSoundEffect.h"
#import "RMAlertView.h"


@interface RMTelepresenceIncomingCallVC () <RMVoiceDelegate>

@property (nonatomic, strong) RMSoundEffect *ringTone;

@end

@implementation RMTelepresenceIncomingCallVC

#pragma mark - UIViewController Lifecycle

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(rejectIncomingCall) object:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self performSelector:@selector(rejectIncomingCall) withObject:nil afterDelay:60.0];
    
    self.ringTone = [RMSoundEffect effectWithName:@"Romo-Ringtone-Full-Bodied"];
    self.ringTone.repeats = YES;
    [self.ringTone play];
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    [RMAlertView dismissAll];
    
    DDLogVerbose(@"Presenting accept/decline voice.");
    
    [self.Romo.voice dismissImmediately];
    
    self.Romo.voice.delegate = self;
    [self.Romo.voice ask:NSLocalizedString(@"TP-Incoming-Call-Prompt", @"Incoming call!") withAnswers:@[NSLocalizedString(@"TP-Incoming-Call-No", @"Reject"), NSLocalizedString(@"TP-Incoming-Call-Yes", @"Answer Call")]];
}

- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(rejectIncomingCall) object:nil];
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    return RMRomoFunctionalityCharacter;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    return RMRomoInterruptionNone;
}

#pragma mark - Handling the Call

- (void)acceptIncomingCall
{
    if (self.callAcceptedHandler) {
        self.callAcceptedHandler();
    }
}

- (void)rejectIncomingCall
{
    if (self.callRejectedHandler) {
        self.callRejectedHandler();
    }
}

#pragma mark - RMVoiceDelegate

- (void)userDidSelectOptionAtIndex:(int)optionIndex forVoice:(RMVoice *)voice;
{
    [self.Romo.voice dismiss];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(rejectIncomingCall) object:nil];
    
    if (optionIndex == 0) {
        [self rejectIncomingCall];
    }
    else if (optionIndex == 1) {
        [self acceptIncomingCall];
    }
}

@end
