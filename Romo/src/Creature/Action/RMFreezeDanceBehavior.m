//
//  RMFreezeDanceBehavior.m
//  Romo
//
//  Created on 12/5/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import "RMFreezeDanceBehavior.h"

#import "RMRomo.h"
#import "RMSoundEffect.h"

#import <Romo/RMDispatchTimer.h>
#import <Romo/RMMath.h>
#import <Romo/RMMotionDetectionModule.h>

#define kHeadCockAngle      11
#define kBounceAngle        6

#define kDefaultDuration    35 // Seconds to play
#define kFreezeDanceMusic   @"musicFreezeDance"

static const float percentOfPixelsMovingThreshold = 2.5; // percent
static const int consecutiveTriggerCountForConfirmedMotion = 10; // # of frames

//==============================================================================
@interface RMFreezeDanceBehavior () <RMMotionDetectionModuleDelegate>

@property (nonatomic, getter=isDancing, readwrite) BOOL dancing;

@property (nonatomic, strong) RMSoundEffect *music;

@property (nonatomic, strong) RMDispatchTimer *timer;

@property (nonatomic, strong) RMMotionDetectionModule *motionDetection;

@end

//==============================================================================
@implementation RMFreezeDanceBehavior

//------------------------------------------------------------------------------
- (id)initWithRomo:(RMRomo *)Romo
{
    self = [super init];
    if (self) {
        _music = [[RMSoundEffect alloc] initWithName:kFreezeDanceMusic];
        _music.repeats = YES;
        _music.gain = 1.0;
        
        _duration = kDefaultDuration;
        
        _Romo = Romo;
        _motionDetection = [[RMMotionDetectionModule alloc] initWithVision:_Romo.vision];
        _motionDetection.delegate = self;
        _motionDetection.minimumConsecutiveTriggerCount = consecutiveTriggerCountForConfirmedMotion;
        _motionDetection.minimumPercentageOfPixelsMoving = percentOfPixelsMovingThreshold;
        
        _recordVideo = NO; // Don't record video by default
    }
    return self;
}

//------------------------------------------------------------------------------
- (void)start
{
    if (self.Romo.robot && !self.dancing) {
        [self.Romo.voice say:NSLocalizedString(@"Interaction-FreezeDance-Start", @"Freeze Dance!") withStyle:RMVoiceStyleLSL autoDismiss:YES];
        if (self.recordVideo) {
            [self.Romo.vision activateModuleWithName:RMVisionModule_TakeVideo];
        }
        self.dancing = YES;
        
        [self.Romo.vision activateModule:self.motionDetection];
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.duration * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self stop];
        });
    }
}

//------------------------------------------------------------------------------
- (void)stop
{
    if (self.isDancing) {
        [self.timer stopRunning];
        if (self.recordVideo) {
            [self.Romo.vision deactivateModuleWithName:RMVisionModule_TakeVideo];
        }
        
        [self.Romo.vision deactivateModule:self.motionDetection];
        self.motionDetection = nil;
        
        [RMSoundEffect playForegroundEffectWithName:@"TrainingSound-8" repeats:NO gain:1.0];
        
        self.Romo.character.emotion = RMCharacterEmotionBewildered;
        [self.Romo.character lookAtDefault];
        self.Romo.character.faceRotation = 0.0;
        
        self.dancing = NO;
        self.music = nil;
        
        if (self.completion) {
            self.completion(YES);
        }
    }
}

//------------------------------------------------------------------------------
- (void)motionDetectionModuleDidDetectMotion:(RMMotionDetectionModule *)module
{
    self.Romo.character.emotion = RMCharacterEmotionHappy;
    [self.music play];
    [self.timer startRunning];
}

//------------------------------------------------------------------------------
- (void)motionDetectionModuleDidDetectEndOfMotion:(RMMotionDetectionModule *)module
{
    self.Romo.character.emotion = RMCharacterEmotionIndifferent;
    [self.music pause];
    [self.timer stopRunning];
    
    self.Romo.character.faceRotation = (self.Romo.character.faceRotation <= 0) ? kHeadCockAngle : (kHeadCockAngle * -1);
    [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, -0.4, 0.25) animated:YES];
}

// Nod back and forth and look around
//------------------------------------------------------------------------------
- (void)update
{
    if (self.Romo.character.emotion != RMCharacterEmotionHappy) {
        self.Romo.character.emotion = RMCharacterEmotionHappy;
    }
    if (self.Romo.character.faceRotation > 0) {
        self.Romo.character.faceRotation = kBounceAngle * -1;
        float randLocX = CLAMP(-0.9, randFloat() * -1, -0.2);
        float randLocY = CLAMP(-0.9, randFloat() * -1, -0.2);
        [self.Romo.character lookAtPoint:RMPoint3DMake(randLocX, randLocY, 0.75) animated:YES];
    }
    else if (self.Romo.character.faceRotation <= 0) {
        float randLocX = CLAMP(0.1, randFloat(), 0.9);
        float randLocY = CLAMP(-0.9, randFloat() * -1, -0.2);
        [self.Romo.character lookAtPoint:RMPoint3DMake(randLocX, randLocY, 0.75) animated:YES];
        self.Romo.character.faceRotation = kBounceAngle;
    }
}

//------------------------------------------------------------------------------
- (RMDispatchTimer *)timer
{
    if (!_timer) {
        _timer = [[RMDispatchTimer alloc] initWithQueue:dispatch_get_main_queue() frequency:2.1];
        __weak RMFreezeDanceBehavior *weakSelf = self;
        _timer.eventHandler = ^{
            [weakSelf update];
        };
    }
    return _timer;
}

@end
