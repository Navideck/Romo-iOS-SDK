//
//  RMActionRunner.m
//  Romo
//

#import "RMActionRunner.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <Romo/RMVision.h>
#import <Romo/RMMath.h>
#import "RMAction.h"
#import "RMRomo.h"
#import "RMActionRuntime.h"
#import "RMAction.h"
#import "RMParameter.h"
#import "RMDoodle.h"
#import "RMSoundEffect.h"
#import "RMExploreBehavior.h"

static NSString *actionDefinitionsFileName = @"RMActions";

/** Top speed a robot can drive */
static const float topSpeedMetersPerSecond = 0.67;

/** Speed for straight-aways in Romo Doodle */
static const float doodleDriveForwardSpeed = 0.50;

/** How far Romo should look to the side when turning */
static const float turningGazeAmount = 0.8;

/** How far Romo should look to the side when tilting */
static const float tiltingGazeAmount = 1.0;

@interface RMActionRunner ()

@property (nonatomic) BOOL waitingForItemToBegin;
@property (nonatomic) BOOL waitingForItemToStop;
@property (nonatomic, strong) MPMediaItem *currentlyPlayingItem;

@property (nonatomic, getter=isExpressing) BOOL expressing;
@property (nonatomic) BOOL ignoreExpressionDidFinish;
@property (nonatomic) RMCharacterExpression queuedExpression;

@property (nonatomic) int doodleActionIncrement;

@property (nonatomic, strong) RMSoundEffect *soundEffect;

@property (nonatomic, strong, readwrite) RMExploreBehavior *exploreBehavior;

@end

@implementation RMActionRunner

#pragma mark - Class Methods

+ (NSArray *)actions
{
    static NSMutableArray *actions = nil;
    if (!actions) {
        NSString *resourceFile = [[NSBundle mainBundle] pathForResource:actionDefinitionsFileName ofType:@"plist"];
        NSArray *actionsData = [NSArray arrayWithContentsOfFile:resourceFile];
        
        actions = [NSMutableArray arrayWithCapacity:actionsData.count];
        for (NSDictionary *actionDictionary in actionsData) {
            RMAction *action = [[RMAction alloc] initWithDictionary:actionDictionary];
            [actions addObject:action];
        }
    }
    return actions;
}

#pragma mark - Public Methods

- (void)stopExecution
{
    if (self.isExpressing) {
        self.ignoreExpressionDidFinish = YES;
        self.expressing = NO;
    }
    
    RMCoreRobot<LEDProtocol, DifferentialDriveProtocol, HeadTiltProtocol> *robot = (RMCoreRobot<LEDProtocol, DifferentialDriveProtocol, HeadTiltProtocol> *)self.Romo.robot;
    [robot stopAllMotion];
    
    [self.Romo.voice dismiss];
    
    [self.vision deactivateModuleWithName:RMVisionModule_TakeVideo];
    
    // This tells the currently running doodle that it's expired
    self.doodleActionIncrement++;
    
    if (self.currentlyPlayingItem) {
        [[MPMusicPlayerController systemMusicPlayer] stop];
    }
}

- (void)dealloc
{
    [self stopExploring];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Driving

- (void)driveForwardWithSpeed:(NSNumber *)speed distance:(NSNumber *)distance
{
    if (self.Romo.robot.isDrivable) {
        [self driveWithSpeed:speed.floatValue / 100.0
                    distance:distance.floatValue / 100.0
                     forward:YES
                  completion:^{
                      [self.delegate runnerBecameReadyToContinueExecution:self];
                  }];
    } else {
        [self.delegate runnerBecameReadyToContinueExecution:self];
    }
}

- (void)driveBackwardWithSpeed:(NSNumber *)speed distance:(NSNumber *)distance
{
    if (self.Romo.robot.isDrivable) {
        [self driveWithSpeed:speed.floatValue / 100.0
                    distance:distance.floatValue / 100.0
                     forward:NO
                  completion:^{
                      [self.delegate runnerBecameReadyToContinueExecution:self];
                  }];
    } else {
        [self.delegate runnerBecameReadyToContinueExecution:self];
    }
}

- (void)turnByAngle:(NSNumber *)angle radius:(NSNumber *)radius clockwise:(NSNumber *)clockwise
{
    if (self.Romo.robot.isDrivable) {
        RMCoreRobot<DriveProtocol, RobotMotionProtocol> *robot = self.Romo.robot;
        
        [robot stopDriving];
        
        BOOL turnClockwise = clockwise.boolValue;
        float turnByAngle = angle.floatValue * (turnClockwise ? -1 : 1);
        float turnRadius = radius.floatValue / 100.0;
        
        __block float initialHeading = robot.platformAttitude.yaw;
        
        [self.Romo.character lookAtPoint:RMPoint3DMake((turnClockwise ? -1.0 : 1.0) * turningGazeAmount, -0.1, 0.2) animated:YES];

        [robot turnByAngle:turnByAngle
                withRadius:turnRadius
           finishingAction:RMCoreTurnFinishingActionStopDriving
                completion:^(BOOL success, float heading){
                    [robot stopDriving];
                    [self.Romo.character lookAtDefault];
                    
                    float actualTurnAngle = heading - initialHeading;
                    if (actualTurnAngle < 0) {
                        actualTurnAngle += 360;
                    }
                    if (turnClockwise) {
                        actualTurnAngle = 360 - actualTurnAngle;
                    }
                    [self updateRunningActionToAngle:actualTurnAngle];
                    [self.delegate runnerBecameReadyToContinueExecution:self];
                }];
    } else {
        [self updateRunningActionToAngle:0];
        [self.delegate runnerBecameReadyToContinueExecution:self];
    }
}

#pragma mark - Doodle

- (void)doodle:(RMDoodle *)doodle
{
    if (self.Romo.robot.isDrivable) {
        self.doodleActionIncrement++;
        
        // Draw the doodle starting with the first action
        [doodle computeDriveActions];
        [self executeActionAtIndex:0 doodle:doodle incrementKey:self.doodleActionIncrement completion:^{
            [self.delegate runnerBecameReadyToContinueExecution:self];
        }];
    } else {
        [self.delegate runnerBecameReadyToContinueExecution:self];
    }
}

- (void)executeActionAtIndex:(int)index doodle:(RMDoodle *)doodle incrementKey:(int)incrementKey completion:(void (^)(void))completion
{
    if (self.doodleActionIncrement != incrementKey) {
        // If a newer doodle action was called, or we exited the mission, this forces us to end early
        return;
    }
    
    if (index < doodle.driveActions.count) {
        NSDictionary *action = doodle.driveActions[index];
        BOOL driveForward = [action[@"forward"] boolValue];
        BOOL turn = [action[@"turn"] boolValue];
        
        void (^actionCompletion)(void) = ^{
            [self executeActionAtIndex:index + 1 doodle:doodle incrementKey:incrementKey completion:completion];
        };
        
        if (driveForward) {
            float distance = [action[@"distance"] floatValue];
            [self driveWithSpeed:doodleDriveForwardSpeed
                        distance:distance
                         forward:YES
                      completion:actionCompletion];
        } else if (turn) {
            float angle = [action[@"angle"] floatValue];
            float radius = [action[@"radius"] floatValue];
            BOOL clockwise = [action[@"clockwise"] boolValue];

            [self.Romo.character lookAtPoint:RMPoint3DMake((clockwise ? 1.0 : -1.0) * turningGazeAmount, -0.1, 0.2) animated:YES];
            [self.Romo.robot turnByAngle:angle * (clockwise ? 1.0 : -1.0)
                              withRadius:radius
                         finishingAction:RMCoreTurnFinishingActionStopDriving
                              completion:^(BOOL success, float heading) {
                                  [self.Romo.character lookAtDefault];
                                  actionCompletion();
                              }];
        } else {
            NSException *exception = [[NSException alloc] initWithName:@"Executing Romo Doodle Failed"
                                                                reason:@"The action was not forward or turn"
                                                              userInfo:action];
            [exception raise];
        }
    } else {
        if (completion) {
            completion();
        }
    }
}

- (void)driveWithSpeed:(float)speed distance:(float)distance forward:(BOOL)forward completion:(void (^)(void))completion
{
    RMCoreRobot<DriveProtocol> *robot = self.Romo.robot;

    // Fact: Robot speed vs. time is not a linear function
    // e.g. telling a robot to drive at 40% speed for 10 sec doesn't drive half as far as 80% speed
    // After a whole lot of samples, I found that speeds were most normal around 50%,
    // and varied much more at the extremes, in function that looks like distance = speed^3
    // I came up with these entirely magical numbers that seem to work quite well...
    // In all testing that I've done, driving 10% for 16 sec ends up within a few cm of 20% for 8 sec or 80% for 2 sec
    // If you want to update this at some point in the future, I suggest starting from scratch rather than trying to tweak any of these values
    float normalizeForSpeed = ((powf(0.06 * ((100 * speed) - 50), 3) + 85.0)) / 112.0;
    float distanceInMeters = distance * normalizeForSpeed;
    
    float metersPerSecondAtSpeed = topSpeedMetersPerSecond * speed;
    float secondsAtSpeed = distanceInMeters / metersPerSecondAtSpeed;
    
    if (forward) {
        [robot driveForwardWithSpeed:speed];
    } else {
        [robot driveBackwardWithSpeed:speed];
    }
    
    double delayInSeconds = secondsAtSpeed;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [robot stopDriving];
        if (completion) {
            completion();
        }
    });
}

#pragma mark - Tilting

- (void)tiltToAngle:(NSNumber *)angle
{
    if (self.Romo.robot.isHeadTiltable) {
        RMCoreRobot<HeadTiltProtocol> *robot = (RMCoreRobot<HeadTiltProtocol> *)self.Romo.robot;
       
        // Shift Romo's gaze to match the tilt
        BOOL isLookingUp = angle.floatValue > robot.headAngle;
        [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, (isLookingUp ? -1 : 1) * tiltingGazeAmount, 0.2) animated:YES];
        
        [robot tiltToAngle:angle.floatValue completion:^(BOOL success) {
            [self.Romo.character lookAtDefault];
            
            for (RMParameter *parameter in self.runningAction.parameters) {
                if (parameter.type == RMParameterAngle) {
                    parameter.value = @(robot.headAngle);
                }
            }
            [self.delegate runnerBecameReadyToContinueExecution:self];
        }];
    } else {
        [self.delegate runnerBecameReadyToContinueExecution:self];
    }
}

#pragma mark - LED Light

- (void)turnOnLights:(NSNumber *)brightness
{
    if (self.Romo.robot.isLEDEquipped) {
        RMCoreRobot<LEDProtocol> *robot = (RMCoreRobot<LEDProtocol> *)self.Romo.robot;
        [robot.LEDs setSolidWithBrightness:(brightness.floatValue / 100.0)];
        
        double delayInSeconds = 0.35;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.delegate runnerBecameReadyToContinueExecution:self];
        });
    } else {
        [self.delegate runnerBecameReadyToContinueExecution:self];
    }
}

- (void)turnOffLights
{
    if (self.Romo.robot.isLEDEquipped) {
        RMCoreRobot<LEDProtocol> *robot = (RMCoreRobot<LEDProtocol> *)self.Romo.robot;
        [robot.LEDs turnOff];
        
        double delayInSeconds = 0.35;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.delegate runnerBecameReadyToContinueExecution:self];
        });
    } else {
        [self.delegate runnerBecameReadyToContinueExecution:self];
    }
}

- (void)blinkLights
{
    if (self.Romo.robot.isLEDEquipped) {
        RMCoreRobot<LEDProtocol> *robot = (RMCoreRobot<LEDProtocol> *)self.Romo.robot;
        [robot.LEDs blinkWithPeriod:0.75 dutyCycle:0.5];
        
        double delayInSeconds = 0.75;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.delegate runnerBecameReadyToContinueExecution:self];
        });
    } else {
        [self.delegate runnerBecameReadyToContinueExecution:self];
    }
}

#pragma mark - Character

- (void)express:(NSNumber *)expressionValue
{
    if (self.isExpressing || self.ignoreExpressionDidFinish) {
        self.queuedExpression = expressionValue.intValue;
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCharacterDidFinishExpressingNotification:)
                                                     name:RMCharacterDidFinishExpressingNotification
                                                   object:nil];
        
        self.expressing = YES;
        RMCharacterExpression expression = expressionValue.intValue;
        RMCharacterEmotion contextualEmotion = [self contextualEmotionForExpression:expression];
        [self.Romo.character setExpression:expression withEmotion:contextualEmotion];
    }
}

- (void)emote:(NSNumber *)emotion
{
    self.Romo.character.emotion = (RMCharacterEmotion)emotion.intValue;
    
    double delayInSeconds = 0.65;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.delegate runnerBecameReadyToContinueExecution:self];
    });
}

- (void)lookAtPoint:(NSString *)point
{
    NSRange comma = [point rangeOfString:@", "];
    CGFloat x = [[point substringToIndex:comma.location] floatValue];
    CGFloat y = [[point substringFromIndex:comma.location + comma.length] floatValue];
    CGPoint lookAtPoint = CGPointMake(x, y);
    [self.Romo.character lookAtPoint:RMPoint3DMake(lookAtPoint.x, lookAtPoint.y, 0.75) animated:YES];
    
    double delayInSeconds = 0.25;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.delegate runnerBecameReadyToContinueExecution:self];
    });
}

- (void)say:(NSString *)say
{
    [self.Romo.character mumble];
    [self.Romo.voice say:say withStyle:RMVoiceStyleLSL autoDismiss:YES];
    
    double delayInSeconds = self.Romo.voice.duration + 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.delegate runnerBecameReadyToContinueExecution:self];
    });
}

- (void)fart
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleCharacterDidFinishExpressingNotification:)
                                                 name:RMCharacterDidFinishExpressingNotification
                                               object:nil];
    
    enableRomotions(YES, self.Romo);
    self.Romo.character.expression = RMCharacterExpressionFart;
}

- (void)changeFaceColor:(UIColor *)faceColor
{
    [self.Romo.character setFillColor:faceColor percentage:100.0];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        [self.delegate runnerBecameReadyToContinueExecution:self];
    });
}

#pragma mark - Camera

- (void)takePhoto
{
    // Wink while taking the picture
    [self.Romo.character setLeftEyeOpen:NO rightEyeOpen:YES];

    [self.vision activateModuleWithName:RMVisionModule_TakePicture];
    
    static const int numberOfCameraSounds = 5;
    [RMSoundEffect playForegroundEffectWithName:[NSString stringWithFormat:@"Camera%d", arc4random() % numberOfCameraSounds] repeats:NO gain:1.0];
    
    double delayInSeconds = 0.35;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.Romo.character setLeftEyeOpen:YES rightEyeOpen:YES];
        [self.delegate runnerBecameReadyToContinueExecution:self];
    });
}

- (void)recordVideoForDuration:(NSNumber *)duration
{
    [self.vision activateModuleWithName:RMVisionModule_TakeVideo];
    
    double delayInSeconds = duration.floatValue;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.vision deactivateModuleWithName:RMVisionModule_TakeVideo];
        [self.delegate runnerBecameReadyToContinueExecution:self];
    });
}

#pragma mark - Pausing

- (void)waitForDuration:(NSNumber *)duration
{
    double delayInSeconds = duration.floatValue;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.delegate runnerBecameReadyToContinueExecution:self];
    });
}

#pragma mark - Music

- (void)playSong:(NSNumber *)songID
{
    MPMediaItem *song = nil;
    MPMediaQuery *allSongs = [MPMediaQuery songsQuery];
    for (MPMediaItem *someSong in allSongs.items) {
        if ([[someSong valueForProperty:MPMediaItemPropertyPersistentID] intValue] == songID.intValue) {
            song = someSong;
            break;
        }
    }
    
    if (song) {
        self.currentlyPlayingItem = song;
        self.waitingForItemToBegin = YES;
        self.waitingForItemToStop = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateDidChange:)
                                                     name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingItemDidChange:)
                                                     name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:nil];
        
        MPMusicPlayerController *player = [MPMusicPlayerController systemMusicPlayer];
        [player beginGeneratingPlaybackNotifications];
        [player setQueueWithItemCollection:[[MPMediaItemCollection alloc] initWithItems:@[song]]];
        [player setNowPlayingItem:song];
        [player play];
    }
}

- (void)shuffleMusic
{
    MPMediaQuery *allSongs = [MPMediaQuery songsQuery];
    
    if (allSongs.items.count) {
        self.currentlyPlayingItem = allSongs.items[arc4random() % allSongs.items.count];
        self.waitingForItemToBegin = YES;
        self.waitingForItemToStop = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateDidChange:)
                                                     name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingItemDidChange:)
                                                     name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:nil];
        
        MPMusicPlayerController *player = [MPMusicPlayerController systemMusicPlayer];
        [player beginGeneratingPlaybackNotifications];
        [player setQueueWithItemCollection:[[MPMediaItemCollection alloc] initWithItems:@[self.currentlyPlayingItem]]];
        player.nowPlayingItem = self.currentlyPlayingItem;
        [player play];
    }
}

#pragma mark - Sound

- (void)playAlarmSound
{
    NSString *randomAlarmSound = [NSString stringWithFormat:@"alarmSound%d", arc4random() % 13];
    self.soundEffect = [[RMSoundEffect alloc] initWithName:randomAlarmSound];
    [self.soundEffect play];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.soundEffect.duration * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.delegate runnerBecameReadyToContinueExecution:self];
    });
}

#pragma mark - Explore

- (void)startExploring
{
    self.exploreBehavior.Romo = self.Romo;
    [self.exploreBehavior startExploring];
}

- (void)stopExploring
{
    if (_exploreBehavior) {
        [self.exploreBehavior stopExploring];
    }
}

#pragma mark - Private Methods

- (void)updateRunningActionToAngle:(float)angle
{
    for (RMParameter *parameter in self.runningAction.parameters) {
        if (parameter.type == RMParameterAngle) {
            parameter.value = @(angle);
        }
    }
}

- (void)handleCharacterDidFinishExpressingNotification:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:RMCharacterDidFinishExpressingNotification
                                                  object:nil];

    self.expressing = NO;
    if (self.ignoreExpressionDidFinish) {
        self.ignoreExpressionDidFinish = NO;
        if (self.queuedExpression) {
            RMCharacterExpression queuedExpression = self.queuedExpression;
            self.queuedExpression = 0;
            [self express:@(queuedExpression)];
        }
    } else {
        [self.delegate runnerBecameReadyToContinueExecution:self];
    }
}

- (void)playbackStateDidChange:(NSNotification *)notification
{
    MPMusicPlayerController *player = notification.object;
    
    if (self.waitingForItemToBegin && player.playbackState == MPMusicPlaybackStatePlaying) {
        [self musicPlayerDidStartPlaying:player];
    }
}

- (void)nowPlayingItemDidChange:(NSNotification *)notification
{
    MPMusicPlayerController *player = notification.object;
    id playingPersistentID = [player.nowPlayingItem valueForProperty:MPMediaItemPropertyPersistentID];
    id expectedPersistentID = [self.currentlyPlayingItem valueForProperty:MPMediaItemPropertyPersistentID];
    
    if (self.waitingForItemToStop && ![playingPersistentID isEqual:expectedPersistentID] && self.currentlyPlayingItem) {
        [player pause];
        [self musicPlayerDidFinishPlaying:player];
    }
}

- (void)musicPlayerDidStartPlaying:(MPMusicPlayerController *)player
{
    self.waitingForItemToBegin = NO;
    self.waitingForItemToStop = YES;
    
    [self.delegate runnerBecameReadyToContinueExecution:self];
}

- (void)musicPlayerDidFinishPlaying:(MPMusicPlayerController *)player
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.currentlyPlayingItem = nil;
}

- (RMCharacterEmotion)contextualEmotionForExpression:(RMCharacterExpression)expression
{
    switch (expression) {
        case RMCharacterExpressionAngry: return RMCharacterEmotionSad;
        case RMCharacterExpressionBewildered: return RMCharacterEmotionBewildered;
        case RMCharacterExpressionBored: return RMCharacterEmotionCurious;
        case RMCharacterExpressionCurious: return RMCharacterEmotionCurious;
        case RMCharacterExpressionDizzy: return RMCharacterEmotionCurious;
        case RMCharacterExpressionEmbarrassed: return RMCharacterEmotionBewildered;
        case RMCharacterExpressionExcited: return RMCharacterEmotionExcited;
        case RMCharacterExpressionExhausted: return RMCharacterEmotionHappy;
        case RMCharacterExpressionFart: return RMCharacterEmotionExcited;
        case RMCharacterExpressionHappy: return RMCharacterEmotionHappy;
        case RMCharacterExpressionHiccup: return RMCharacterEmotionIndifferent;
        case RMCharacterExpressionHoldingBreath: return RMCharacterEmotionSleepy;
        case RMCharacterExpressionLaugh: return RMCharacterEmotionExcited;
        case RMCharacterExpressionLookingAround: return RMCharacterEmotionCurious;
        case RMCharacterExpressionLove: return RMCharacterEmotionExcited;
        case RMCharacterExpressionNone: return RMCharacterEmotionHappy;
        case RMCharacterExpressionPonder: return RMCharacterEmotionCurious;
        case RMCharacterExpressionSad: return RMCharacterEmotionSad;
        case RMCharacterExpressionScared: return RMCharacterEmotionScared;
        case RMCharacterExpressionSleepy: return RMCharacterEmotionSleepy;
        case RMCharacterExpressionSneeze: return RMCharacterEmotionHappy;
        case RMCharacterExpressionSniff: return RMCharacterEmotionCurious;
        case RMCharacterExpressionTalking: return RMCharacterEmotionHappy;
        case RMCharacterExpressionYawn: return RMCharacterEmotionSleepy;
        case RMCharacterExpressionLetDown: return RMCharacterEmotionSad;
        case RMCharacterExpressionChuckle: return RMCharacterEmotionExcited;
        case RMCharacterExpressionProud: return RMCharacterEmotionHappy;
        case RMCharacterExpressionSmack: return RMCharacterEmotionSad;
        case RMCharacterExpressionStartled: return RMCharacterEmotionScared;
        case RMCharacterExpressionStruggling: return RMCharacterEmotionSad;
        case RMCharacterExpressionWant: return RMCharacterEmotionExcited;
        case RMCharacterExpressionWee: return RMCharacterEmotionExcited;
        case RMCharacterExpressionYippee: return RMCharacterEmotionExcited;
    }
}

- (RMExploreBehavior *)exploreBehavior
{
    if (!_exploreBehavior) {
        _exploreBehavior = [[RMExploreBehavior alloc] init];
    }
    return _exploreBehavior;
}

@end
