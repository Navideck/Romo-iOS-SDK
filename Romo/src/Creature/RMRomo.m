//
//  RMRomo.m
//  Romo
//

#import "RMRomo.h"
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"
#import <Romo/RMMath.h>
#import "RMAppDelegate.h"
#import "RMRobotController.h"
#import "RMProgressManager.h"
#import "RMUnlockable.h"
#import "RMCharacterUnlockedRobotController.h"
#import "RMFirmwareUpdatingRobotController.h"
#import "RMWiFiDriveRobotController.h"
#import "RMSoundEffect.h"
//#import "RMTelepresencePresence.h"

NSString *const RMRomoDidChangeNameNotification = @"RMRomoDidChangeNameNotification";

@interface RMRomo () <RMCoreDelegate, RMCharacterUnlockedDelegate>

@property (nonatomic, strong) RMWiFiDriveRobotController *WiFiDriveController;
@property (nonatomic, readwrite, getter=isBroadcasting) BOOL broadcasting;

@property (nonatomic, readonly) CFAbsoluteTime timeSinceLastDriveCommand;
@property (nonatomic) BOOL draggingPupils;
@property (nonatomic) CFAbsoluteTime lastMotorCommandTime;
@property (nonatomic) CFAbsoluteTime lastPickUpPutDownTime;

/** When we express, we check to see if it's locked, and unlocked it when done */
@property (nonatomic) RMCharacterExpression expressionToBeUnlocked;

/** Readwrite */
//@property (nonatomic, strong, readwrite) RMVision *vision;
@property (nonatomic, strong, readwrite) RMCoreRobotRomo3 *robot;
@property (nonatomic, strong, readwrite) RMCharacter *character;
@property (nonatomic, strong, readwrite) RMEquilibrioception *equilibrioception;
@property (nonatomic, strong, readwrite) RMVoice *voice;
@property (nonatomic, strong, readwrite) RMRomotion *romotions;
@property (nonatomic, strong, readwrite) RMTouch *touch;
@property (nonatomic, strong, readwrite) RMVitals *vitals;
@property (nonatomic, strong, readwrite) RMLoudSoundDetector *loudSoundDetector;

@end

@implementation RMRomo

- (id)init
{
    self = [super init];
    if (self) {
        self.vitals = [[RMVitals alloc] init];
        self.vitals.delegate = self;
        
        self.name = [[NSUserDefaults standardUserDefaults] objectForKey:@"romo-3 romo name"];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationWillEnterForegroundNotification:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationDidEnterBackgroundNotification:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRobotDidChangeDriveCommandNotification:)
                                                     name:RMCoreRobotDriveSpeedDidChangeNotification
                                                   object:nil];

        [RMCore setDelegate:self];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)handleApplicationWillEnterForegroundNotification:(NSNotification *)notification
{
    if (self.broadcasting) {
        self.broadcasting = NO;
        self.broadcasting = YES;
    }
}

- (void)handleApplicationDidEnterBackgroundNotification:(NSNotification *)notification
{
//    [[RMTelepresencePresence sharedInstance] disconnect];
}

#pragma mark - Public Properties --

- (void)setActiveFunctionalities:(RMRomoFunctionalities)activeFunctionalities
{
    _activeFunctionalities = activeFunctionalities;

    // Activate character if requested
    BOOL isCharacterActive = isFunctionalityActive(RMRomoFunctionalityCharacter, activeFunctionalities);
    if (isCharacterActive && self.delegate.characterView) {
        if (![self.delegate.characterView.subviews containsObject:self.touch] || self.voice.view != self.delegate.characterView) {
            [self.character addToSuperview:self.delegate.characterView];
            [self.delegate.characterView addSubview:self.touch];
            self.voice.view = self.delegate.characterView;
        }
    } else {
        [_character removeFromSuperview];
        [_touch removeFromSuperview];
        [_voice removeFromSuperview];
        _character = nil;
        _touch = nil;
        _voice = nil;
    }
    
    BOOL isEquilibrioceptionActive = isFunctionalityActive(RMRomoFunctionalityEquilibrioception, activeFunctionalities);
    if (isEquilibrioceptionActive && self.robot) {
        self.equilibrioception.robot = self.robot;
    } else {
        _equilibrioception = nil;
    }
    
    BOOL isBroadcastingActive = isFunctionalityActive(RMRomoFunctionalityBroadcasting, activeFunctionalities);
    if (isBroadcastingActive) {
        self.broadcasting = YES;
    } else {
        self.broadcasting = NO;
    }
    
    BOOL isVisionActive = isFunctionalityActive(RMRomoFunctionalityVision, activeFunctionalities);
    if (isVisionActive) {
        [self.vision startCapture];
        self.vision.delegate = self.delegate;
    } else if (_vision) {
        NSSet *activeModules = self.vision.activeModules;
        [activeModules enumerateObjectsUsingBlock:^(id<RMVisionModuleProtocol> module, BOOL *stop) {
            [self.vision deactivateModule:module];
        }];
        [self.vision stopCaptureWithCompletion:^(BOOL isRunning) {
            BOOL isVisionActive = isFunctionalityActive(RMRomoFunctionalityVision, self.activeFunctionalities);
            if (!isVisionActive) {
                self.vision = nil;
            }
        }];
    }
    
    BOOL isLoudSoundActive = isFunctionalityActive(RMRomoFunctionalityLoudSound, activeFunctionalities);
    if (isLoudSoundActive) {
        self.loudSoundDetector.delegate = self;
    } else if (_loudSoundDetector) {
        self.loudSoundDetector = nil;
    }
}

- (void)setRobot:(RMCoreRobotRomo3 *)robot
{
    _robot = robot;
    [robot.LEDs setSolidWithBrightness:1.0];

    BOOL isEquilibrioceptionActive = isFunctionalityActive(RMRomoFunctionalityEquilibrioception, self.activeFunctionalities);
    if (isEquilibrioceptionActive) {
        self.equilibrioception.robot = robot;
    }

    self.romotions.robot = self.robot;
}

- (void)setName:(NSString *)name
{
    if (![name isEqualToString:_name]) {
        if (name.length > 16) {
            name = [name substringToIndex:16];
        } else if (!name.length) {
            name = @"";
        }
        
        _name = name;
        
        [[NSUserDefaults standardUserDefaults] setObject:name forKey:@"romo-3 romo name"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:RMRomoDidChangeNameNotification
                                                            object:self
                                                          userInfo:@{@"name" : name}];
    }
}

#pragma mark - Readonly Properties --

- (BOOL)RomoCanLook
{
    return !self.draggingPupils && isFunctionalityActive(RMRomoFunctionalityCharacter, self.activeFunctionalities);
}

- (BOOL)RomoCanDrive
{
    return (self.romotions.romoting == NO);
}

- (RMCharacter *)character
{
    if (!_character && isFunctionalityActive(RMRomoFunctionalityCharacter, self.activeFunctionalities)) {
        _character = [RMCharacter Romo];
        _character.delegate = self;
    }
    return _character;
}

- (RMVision *)vision
{
    if (!_vision) {
        _vision = [[RMVision alloc] init];
    }
    return _vision;
}

- (RMEquilibrioception *)equilibrioception
{
    if (!_equilibrioception) {
        _equilibrioception = [[RMEquilibrioception alloc] init];
        _equilibrioception.delegate = self;
    }
    return _equilibrioception;
}

- (RMLoudSoundDetector *)loudSoundDetector
{
    if (!_loudSoundDetector) {
        _loudSoundDetector = [[RMLoudSoundDetector alloc] init];
        _loudSoundDetector.delegate = self;
    }
    return _loudSoundDetector;
}

- (RMVoice *)voice
{
    if (!_voice) {
        _voice = [RMVoice voice];
        _voice.view = self.view;
    }
    return _voice;
}

- (RMTouch *)touch
{
    if (!_touch) {
        _touch = [[RMTouch alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _touch.delegate = self;
    }
    return _touch;
}

- (RMRomotion *)romotions
{
    if (!_romotions) {
        _romotions = [[RMRomotion alloc] init];
    }
    return _romotions;
}

#pragma mark - RMCoreDelegate

- (void)robotDidConnect:(RMCoreRobot *)robot
{
    if ([robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.robot = (RMCoreRobotRomo3 *)robot;
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    self.robot = nil;
}

#pragma mark - Private Methods --

- (CFAbsoluteTime)timeSinceLastDriveCommand
{
    if (self.robot.isConnected && self.robot.isDrivable && ((RMCoreRobot<DriveProtocol> *)self.robot).isDriving) {
        return 0.0;
    }
    return currentTime() - self.lastMotorCommandTime;
}

#pragma mark - Robot Notifications --

- (void)handleRobotDidChangeDriveCommandNotification:(NSNotification *)notification
{
    self.lastMotorCommandTime = currentTime();
    
    BOOL allowsDizzyInterruption = allowsRomoInterruption(RMRomoInterruptionDizzy, self.allowedInterruptions);
    if (allowsDizzyInterruption && !self.robot.isDriving && self.equilibrioception.isDizzy) {
        self.character.expression = RMCharacterExpressionDizzy;
    }
}

#pragma mark - RMCharacterDelegate --

- (void)characterDidBeginExpressing:(RMCharacter *)character
{
    BOOL allowsRomotionInterruption = allowsRomoInterruption(RMRomoInterruptionRomotion, self.allowedInterruptions);
    if (allowsRomotionInterruption) {
        self.romotions.expression = self.character.expression;
    }
    
    if (self.expressionToBeUnlocked == RMCharacterExpressionNone && character.expression < (RMCharacterExpression)100) {
        self.expressionToBeUnlocked = character.expression;
    }
    
    if ([self.delegate respondsToSelector:@selector(characterDidBeginExpressing:)]) {
        [self.delegate characterDidBeginExpressing:character];
    }
}

- (void)characterDidFinishExpressing:(RMCharacter *)character
{
    if (self.expressionToBeUnlocked != RMCharacterExpressionNone) {
        RMCharacterExpression expression = self.expressionToBeUnlocked;
        self.expressionToBeUnlocked = RMCharacterExpressionNone;

        BOOL newlyUnlocked = [[RMProgressManager sharedInstance] achieveUnlockable:[RMUnlockable unlockableWithExpression:expression]];
        BOOL allowsUnlockingInterruption = allowsRomoInterruption(RMRomoInterruptionCharacterUnlocks, self.allowedInterruptions);
        if (newlyUnlocked && allowsUnlockingInterruption) {
            RMCharacterUnlockedRobotController *unlockedVC = [[RMCharacterUnlockedRobotController alloc] initWithExpression:expression];
            unlockedVC.autoDismissInterval = 8;
            unlockedVC.delegate = self;
            [(RMAppDelegate *)[UIApplication sharedApplication].delegate pushRobotController:unlockedVC];
        }
    }

    if ([self.delegate respondsToSelector:@selector(characterDidFinishExpressing:)]) {
        [self.delegate characterDidFinishExpressing:character];
    }
}

#pragma mark - RMTouchDelegate --

- (UIView *)view
{
    return self.delegate.characterView;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.vitals wakeUp];
    
    if ([self.delegate respondsToSelector:@selector(touchesBegan:withEvent:)]) {
        [self.delegate touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    BOOL wasDraggingPupils = self.draggingPupils;
    self.draggingPupils = YES;
    
    CGPoint location = [[touches anyObject] locationInView:self.view];
    CGFloat x = 0.6*(location.x - self.view.width/2)/(self.view.width/2);
    CGFloat y = 0.8*(location.y - self.view.height/2)/(self.view.height/2);
    
    [self.character lookAtPoint:RMPoint3DMake(x, y, 0.0) animated:!wasDraggingPupils];
    [self.vitals wakeUp];
    
    if ([self.delegate respondsToSelector:@selector(touchesMoved:withEvent:)]) {
        [self.delegate touchesMoved:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.draggingPupils = NO;
    
    [self.character lookAtDefault];
    [self.character setLeftEyeOpen:YES rightEyeOpen:YES];
    [self.vitals wakeUp];
    
    if ([self.delegate respondsToSelector:@selector(touchesEnded:withEvent:)]) {
        [self.delegate touchesEnded:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.draggingPupils = NO;
    
    [self.character lookAtDefault];
    [self.character setLeftEyeOpen:YES rightEyeOpen:YES];
    [self.vitals wakeUp];
    
    if ([self.delegate respondsToSelector:@selector(touchesCancelled:withEvent:)]) {
        [self.delegate touchesCancelled:touches withEvent:event];
    }
}

- (void)touch:(RMTouch *)touch beganPokingAtLocation:(RMTouchLocation)location
{
    if (location == RMTouchLocationLeftEye || location == RMTouchLocationRightEye) {
        NSString *randomPokeSound = [NSString stringWithFormat:@"EyePoke-%d", arc4random_uniform(kNumPokeSounds)];
        [RMSoundEffect playForegroundEffectWithName:randomPokeSound repeats:NO gain:0.4];
    }
    switch (location) {
        case RMTouchLocationLeftEye:
            self.character.leftEyeOpen = NO;
            break;
            
        case RMTouchLocationRightEye:
            self.character.rightEyeOpen = NO;
            break;
            
        default:
            break;
    }
    if ([self.delegate respondsToSelector:@selector(touch:beganPokingAtLocation:)]) {
        [self.delegate touch:touch beganPokingAtLocation:location];
    }
}

- (void)touch:(RMTouch *)touch endedPokingAtLocation:(RMTouchLocation)location
{
    if ([self.delegate respondsToSelector:@selector(touch:endedPokingAtLocation:)]) {
        [self.delegate touch:touch endedPokingAtLocation:location];
    }
}

- (void)touch:(RMTouch *)touch cancelledPokingAtLocation:(RMTouchLocation)location
{
    if ([self.delegate respondsToSelector:@selector(touch:cancelledPokingAtLocation:)]) {
        [self.delegate touch:touch cancelledPokingAtLocation:location];
    }
}

- (void)touch:(RMTouch *)touch detectedTickleAtLocation:(RMTouchLocation)location
{
    if ([self.delegate respondsToSelector:@selector(touch:detectedTickleAtLocation:)]) {
        [self.delegate touch:touch detectedTickleAtLocation:location];
    }
}

#pragma mark - RMEquilibrioceptionDelegate --

- (void)robotDidFlipToOrientation:(RMRobotOrientation)orientation
{
    BOOL allowsSelfRighting = allowsRomoInterruption(RMRomoInterruptionSelfRighting, self.allowedInterruptions);
    if (allowsSelfRighting && self.timeSinceLastDriveCommand < 2.0) {
        [self.robot stopAllMotion];
        [self.romotions stopRomoting];
        
        switch (orientation) {
            case RMRobotOrientationBackSide:
                [self.romotions flipFromBackSide];
                break;
                
            case RMRobotOrientationFrontSide:
                [self.romotions flipFromFrontSide];
                break;
                
            case RMRobotOrientationLeftSide:
            case RMRobotOrientationRightSide:
                self.character.expression = RMCharacterExpressionSad;
                break;
                
            case RMRobotOrientationUpright:
                [self.romotions stopRomoting];
                [self.equilibrioception.robot takeDeviceReferenceAttitude];
                self.character.expression = RMCharacterExpressionExcited;
                break;
        }
        
        if ([self.delegate respondsToSelector:@selector(robotDidFlipToOrientation:)]) {
            [self.delegate robotDidFlipToOrientation:orientation];
        }
    }
}

- (void)robotDidDetectPickup
{
    double time = currentTime();
    if (time - self.lastPickUpPutDownTime > 0.5) {
        self.lastPickUpPutDownTime = time;
        [self.vitals wakeUp];
        
        if ([self.delegate respondsToSelector:@selector(robotDidDetectPickup)]) {
            [self.delegate robotDidDetectPickup];
        }
    }
}

- (void)robotDidDetectPutDown
{
    double time = currentTime();
    if (time - self.lastPickUpPutDownTime > 0.5) {
        self.lastPickUpPutDownTime = time;
        [self.vitals wakeUp];
        
        if ([self.delegate respondsToSelector:@selector(robotDidDetectPutDown)]) {
            [self.delegate robotDidDetectPutDown];
        }
    }
}

- (void)robotDidDetectShake
{
    [self.vitals wakeUp];
    
    if ([self.delegate respondsToSelector:@selector(robotDidDetectShake)]) {
        [self.delegate robotDidDetectShake];
    }
}

- (void)robotDidStartClimbing
{
    [self.vitals wakeUp];
    
    if ([self.delegate respondsToSelector:@selector(robotDidStartClimbing)]) {
        [self.delegate robotDidStartClimbing];
    }
}

#pragma mark - RMLoudSoundDetectorDelegate

- (void)loudSoundDetectorDetectedLoudSound:(RMLoudSoundDetector *)loudSoundDetector
{
    [self.vitals wakeUp];
    
    if ([self.delegate respondsToSelector:@selector(loudSoundDetectorDetectedLoudSound:)]) {
        [self.delegate loudSoundDetectorDetectedLoudSound:loudSoundDetector];
    }
}

- (void)loudSoundDetectorDetectedEndOfLoudSound:(RMLoudSoundDetector *)loudSoundDetector
{
    [self.vitals wakeUp];
    
    if ([self.delegate respondsToSelector:@selector(loudSoundDetectorDetectedEndOfLoudSound:)]) {
        [self.delegate loudSoundDetectorDetectedEndOfLoudSound:loudSoundDetector];
    }
}

#pragma mark - RMVitalsDelegate

- (void)robotDidChangeWakefulness:(RMVitalsWakefulness)wakefulness
{
    BOOL allowsWakefulnessInterruption = allowsRomoInterruption(RMRomoInterruptionWakefulness, self.allowedInterruptions);
    if (allowsWakefulnessInterruption) {
        switch (wakefulness) {
            case RMVitalsWakefulnessAwake:
                self.character.emotion = RMCharacterEmotionHappy;
                break;
                
            case RMVitalsWakefulnessSleepy:
                self.character.emotion = RMCharacterEmotionSleepy;
                break;
                
            case RMVitalsWakefulnessAsleep:
                self.character.emotion = RMCharacterEmotionSleeping;
                break;
                
            default:
                break;
        }
    }
}

#pragma mark - RMCharacterUnlockedVC

- (void)dismissCharacterUnlockedVC:(RMCharacterUnlockedRobotController *)unlockedVC
{
    [(RMAppDelegate *)[UIApplication sharedApplication].delegate popRobotController];
}

#pragma mark - Broadcasting

- (void)setBroadcasting:(BOOL)broadcasting
{
    if (broadcasting != _broadcasting) {
        _broadcasting = broadcasting;
        
#ifndef SIMULATOR
        if (broadcasting) {
//            [[RMTelepresencePresence sharedInstance] connect];
            
            if (!self.WiFiDriveController) {
                self.WiFiDriveController = [[RMWiFiDriveRobotController alloc] init];
            }
            self.WiFiDriveController.broadcasting = YES;
            
        } else {
            self.WiFiDriveController.broadcasting = NO;
            
//            [[RMTelepresencePresence sharedInstance] disconnect];
        }
#endif
    }
}

@end
