//
//  RMCreatureViewController.m
//  Romo
//

#import "RMCreatureRobotController.h"
#import <Romo/RMVision.h>
#import <Romo/RMImageUtils.h>
#import <Romo/RMVisionDebugBroker.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMAppDelegate.h"
#import <Romo/RMMath.h>
#import "RMMissionRobotController.h"
#import "RMBehaviorManager.h"
#import "RMInfoRobotController.h"
#import "RMInteractionScriptRuntime.h"
#import <Romo/RMMath.h>
#import "RMActivityMotivation.h"
#import "RMMission.h"
#import "RMSandboxMission.h"
#import "RMUnlockable.h"
#import "RMSoundEffect.h"
#import <CocoaLumberjack/DDLog.h>
#import "RMMissionRuntime.h"
#import "RMRomoMemory.h"
#import "RMRealtimeAudio.h"
#import "RMMicLineView.h"
#import "RMActivityChooserRobotController.h"

#import "RMJuvenileCreatureRobotController.h"
#import "RMMatureCreatureRobotController.h"

#import "RMFavoriteColorRobotController.h"
#import "RMChaseRobotController.h"
#import "RMLineFollowRobotController.h"

#import "RMInteractionScriptSelectorViewController.h"

static const float kSleepyTickTimeThreshold = 40.0;
//static const float kFaceCloseTimeout = 20.0;
//static const float kFaceCloseDistance = 16.0;
//static const float kBoredRecurringTimeout = 30.0;
//static const float kSleepTimeout = 130.0;

/** Poking Romo's eyes this many times quickly makes him angry */
static const int minimumRapidEyePokeCountToGetAngry = 5;

/** How quickly rapid eye pokes should "decay" (sec) */
static const float rapidEyePokeCountDecrementDelay = 3.25;

@interface RMCreatureRobotController () <RMActivityRobotControllerDelegate, RMVoiceDelegate, RMRealtimeAudioDelegate>

// Timing
@property (nonatomic) double boredStartTime;
@property (nonatomic) double lastFacePromptedSleepyTick;

@property (nonatomic, strong) NSTimer *lookBackTimer;

// Eye Pokes
@property (nonatomic) int rapidEyePokeCount;

/** The current motivated activity */
@property (nonatomic, strong) NSDictionary *currentMotivation;

// The microphone view
@property (nonatomic, strong) RMMicLineView *micView;

// Behavioral helpers - TODO - move these for 2.7
// Tilting
@property (nonatomic) int numTiltCommands;
@property (nonatomic) int numCurrentTiltCommand;
@property (nonatomic) int lastTiltCommand;

// Turning
@property (nonatomic) int numTurnCommands;
@property (nonatomic) int numCurrentTurnCommand;
@property (nonatomic) int lastTurnCommand;

// Moving
@property (nonatomic) int numMoveCommands;
@property (nonatomic) int numCurrentMoveCommand;
@property (nonatomic) float lastMoveCommand;

@property (nonatomic) BOOL ignoreDidBecomeActive;

@end

@implementation RMCreatureRobotController

//------------------------------------------------------------------------------
- (void)controllerWillBecomeActive
{
    [super controllerWillBecomeActive];
    self.isPickedUp = NO;
    
    self.lastFacePromptedSleepyTick = currentTime() - kSleepyTickTimeThreshold;
    
    self.delegate = self;
    
#ifdef DEBUG
    UITapGestureRecognizer *fourFingerQuadTap = [[UITapGestureRecognizer alloc] initWithTarget:[RMProgressManager sharedInstance]
                                                                                        action:@selector(resetProgress)];
    fourFingerQuadTap.numberOfTouchesRequired = 4;
    fourFingerQuadTap.numberOfTapsRequired = 4;
    [self.view addGestureRecognizer:fourFingerQuadTap];
    
    
    UIPanGestureRecognizer *threeFingerPan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(handleDebugPanGesture:)];
    threeFingerPan.maximumNumberOfTouches = 3;
    threeFingerPan.minimumNumberOfTouches = 3;
    [self.view addGestureRecognizer:threeFingerPan];
#endif
}

//------------------------------------------------------------------------------
- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    if (self.ignoreDidBecomeActive) {
        // We end up here when rapidly popping then pushing a new robot controller
        self.ignoreDidBecomeActive = NO;
        return;
    }
    
    // Register app to receive push notifications
//    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
//                                                                           UIRemoteNotificationTypeAlert |
//                                                                           UIRemoteNotificationTypeSound)];
    // Ensure we have a fresh robot object
    if ([self.Romo.robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.robot = (RMCoreRobotRomo3 *)self.Romo.robot;
    }
    
    self.Romo.voice.delegate = self;
    
    // Enable Romotions and set up motivation / behavior managers
    self.motivationManager = [[RMMotivationManager alloc] initWithCharacter:self.Romo.character];
    
    // Get current progress in chapter
    self.currentStoryElement = [self filenameForMission:self.chapterProgress inChapter:self.chapter];
    
    // If there's a story element script to run, do it!
    if ([self hasStoryElementForMission:self.chapterProgress inChapter:self.chapter]) {
        RMStoryStatus currentElementStatus = [[RMProgressManager sharedInstance] storyStatusForElement:self.currentStoryElement];
#ifdef ALWAYS_REVEAL_STORY_ELEMENT
        if (!self.currentStoryElementHasBeenRevealed) {
            currentElementStatus = RMStoryStatusHidden;
        }
#endif
        if (currentElementStatus == RMStoryStatusHidden) {
            self.currentStoryElementHasBeenRevealed = NO;
            [self revealStoryElementInScript:self.currentStoryElement];
        } else {
            self.currentStoryElementHasBeenRevealed = YES;
        }
    } else {
        self.currentStoryElementHasBeenRevealed = YES;
    }
    
#ifdef CREATURE_DEBUG
    [self initDebug];
#endif
    
    self.idleMovementEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"idleMovementEnabled"];
    
}

//------------------------------------------------------------------------------
- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    
    self.listening = NO;
    
    [self.lookBackTimer invalidate];
}

//------------------------------------------------------------------------------
- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    return RMRomoFunctionalityBroadcasting | RMRomoFunctionalityCharacter | RMRomoFunctionalityEquilibrioception;
}

//------------------------------------------------------------------------------
- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    // Disable wakefulness - let the motivation manager take care of that.
    return disableInterruption(RMRomoInterruptionWakefulness, RMRomoInterruptionAll);
}

- (void)loudSoundDetectorDetectedLoudSound:(RMLoudSoundDetector *)loudSoundDetector
{
    if (self.creatureRespondsToLoudSounds && !self.Romo.robot.isDriving && !self.Romo.robot.isTilting) {
        [self.Romo.vitals wakeUp];
        
        float seed = randFloat();
        BOOL shouldLookAround = seed < 0.1;
        BOOL shouldGetScared = seed < 0.2;

        if (shouldLookAround) {
            // Do the "look around" expression
            self.Romo.character.expression = RMCharacterExpressionLookingAround;
        } else if (shouldGetScared) {
            // Be afraid of the loud sound
            enableRomotions(self.idleMovementEnabled, self.Romo);
            self.Romo.character.expression = RMCharacterExpressionStartled;
        } else {
            // The rest of the time, just let out a hiccup
            self.Romo.character.expression = RMCharacterExpressionHiccup;
        }
    }
}

- (void)loudSoundDetectorDetectedEndOfLoudSound:(RMLoudSoundDetector *)loudSoundDetector
{
    if (self.creatureRespondsToLoudSounds) {
        [self.Romo.vitals wakeUp];
    }
}

#pragma mark - RMActivityRobotController Overrides
//------------------------------------------------------------------------------
- (RMChapter)chapter
{
    return [RMProgressManager sharedInstance].newestChapter;
}

//------------------------------------------------------------------------------
- (int)chapterProgress
{
    return [[RMProgressManager sharedInstance] successfulMissionCountForChapter:self.chapter];
}

//------------------------------------------------------------------------------
- (NSString *)title
{
    return nil;
}

//------------------------------------------------------------------------------
- (BOOL)showsHelpButton
{
    return YES;
}

//------------------------------------------------------------------------------
- (BOOL)showsSpaceButton
{
    // Don't show space button on 1-1
    return !([RMProgressManager sharedInstance].newestChapter == RMChapterOne && [RMProgressManager sharedInstance].newestMission == 1);
}

//------------------------------------------------------------------------------
- (void)userAskedForHelp
{
    [RMSoundEffect playForegroundEffectWithName:characterDismissSound repeats:NO gain:1.0];
    RMInfoRobotController *infoRobotController = [[RMInfoRobotController alloc] init];
    ((RMAppDelegate *)[UIApplication sharedApplication].delegate).robotController = infoRobotController;
}

//------------------------------------------------------------------------------
- (void)setAttentive:(BOOL)attentive
{
    if (attentive) {
        if (!self.Romo.voice.visible) {
            self.currentMotivation = [RMActivityMotivation currentMotivation];
            NSString *question = self.currentMotivation[@"question"];
            NSArray *answers = @[self.currentMotivation[@"no"], self.currentMotivation[@"yes"]];
            
            [self.Romo.voice ask:question withAnswers:answers];
        }
    } else {
        [self.Romo.voice dismiss];
    }

    super.attentive = attentive;
}

#pragma mark - RMActivityRobotControllerDelegate

//------------------------------------------------------------------------------
- (void)activityDidFinish:(RMActivityRobotController *)activity
{
    // If the user taps the Space button, transition to that robot controller
    if (activity == self ||
        [activity isKindOfClass:[RMFavoriteColorRobotController class]] ||
        [activity isKindOfClass:[RMChaseRobotController class]] ||
        [activity isKindOfClass:[RMLineFollowRobotController class]]) {
        // We will temporarily become active while we transition robot controllers, so ignore the didBecomeActive message
        self.ignoreDidBecomeActive = YES;
        
        [((RMAppDelegate *)[UIApplication sharedApplication].delegate) popRobotController];
        RMActivityChooserRobotController *chooser = [[RMActivityChooserRobotController alloc] init];
        ((RMAppDelegate *)[UIApplication sharedApplication].delegate).robotController = chooser;
    }
}

#pragma mark - Connection / Disconnection
//------------------------------------------------------------------------------
- (void)robotDidConnect:(RMCoreRobot *)robot
{
    if ([self.Romo.robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.robot = (RMCoreRobotRomo3 *)self.Romo.robot;
    }
    
    [self disableRomotionsIfPickedUp];
    
    NSArray *random = @[@(RMCharacterExpressionCurious),
                        @(RMCharacterExpressionExcited),
                        @(RMCharacterExpressionHappy),
                        @(RMCharacterExpressionLaugh),
                        @(RMCharacterExpressionLookingAround),
                        @(RMCharacterExpressionTalking)];
    
    RMCharacterExpression randomPickupExpression = (RMCharacterExpression)[random[arc4random() % random.count] intValue];
    [self.Romo.character setExpression:randomPickupExpression
                           withEmotion:RMCharacterEmotionHappy];
}

//------------------------------------------------------------------------------
- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    self.robot = nil;
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        NSArray *random = @[@(RMCharacterExpressionSad),
                            @(RMCharacterExpressionAngry)];
        RMCharacterExpression randomPickupExpression = (RMCharacterExpression)[random[arc4random() % random.count] intValue];
        [self.Romo.character setExpression:randomPickupExpression
                               withEmotion:RMCharacterEmotionCurious];
    }
}

#pragma mark - RMCharacterDelegate
//------------------------------------------------------------------------------
- (void)characterDidBeginExpressing:(RMCharacter *)character
{
}

//------------------------------------------------------------------------------
- (void)characterDidFinishExpressing:(RMCharacter *)character
{
}

#pragma mark - RMRomoDelegate

//------------------------------------------------------------------------------
- (void)robotDidDetectPickup
{
    self.isPickedUp = YES;
    enableRomotions(NO, self.Romo);

    if (self.motivationManager.motivation == RMMotivation_Sleep) {
        // If we're asleep, wake up
        self.motivationManager.motivation = RMMotivation_Curiosity;
    }
    
    if ([self creatureShouldReactToPickUpPutDown]) {
        [RMMissionRuntime runUserTrainedAction:RMUserTrainedActionPickedUp
                                        onRomo:self.Romo
                                    completion:nil];
    }
}

//------------------------------------------------------------------------------
- (void)robotDidDetectPutDown
{
    self.isPickedUp = NO;
    enableRomotions(self.idleMovementEnabled, self.Romo);
 
    if ([self creatureShouldReactToPickUpPutDown]) {
        [RMMissionRuntime runUserTrainedAction:RMUserTrainedActionPutDown
                                        onRomo:self.Romo
                                    completion:nil];
    }
}

//------------------------------------------------------------------------------
- (void)robotDidDetectShake
{
    // If the user has taught their Romo this defense mechanism, fart!
    if ([self creatureShouldFartOnShake]) {
        self.Romo.character.expression = RMCharacterExpressionFart;
    }
}

//------------------------------------------------------------------------------
- (void)touch:(RMTouch *)touch detectedTickleAtLocation:(RMTouchLocation)location
{
    BOOL creatureHasCustomTickleReaction = (self.chapter >=2 && self.chapterProgress > kTickleMission);
    
    BOOL shouldUseCustomTickleReaction = creatureHasCustomTickleReaction && (arc4random() % 3 == 0);
    
    if (shouldUseCustomTickleReaction) {
        RMUserTrainedAction action = 0;
        switch (location) {
            case RMTouchLocationChin: action = RMUserTrainedActionTickleChin; break;
            case RMTouchLocationNose: action = RMUserTrainedActionTickleNose; break;
            case RMTouchLocationForehead: action = RMUserTrainedActionTickleForehead; break;
            default: break;
        }
        [RMMissionRuntime runUserTrainedAction:action
                                        onRomo:self.Romo
                                    completion:nil];
    } else {
        switch (location) {
            case RMTouchLocationNose: {
                [self disableRomotionsIfPickedUp];
                self.Romo.character.expression = RMCharacterExpressionSneeze;
                break;
            }
                
            case RMTouchLocationChin: {
                [self disableRomotionsIfPickedUp];
                self.Romo.character.expression = RMCharacterExpressionChuckle;
                break;
            }
                
            default:
                break;
        }
    }
}

//------------------------------------------------------------------------------
- (void)touch:(RMTouch *)touch beganPokingAtLocation:(RMTouchLocation)location
{
    self.motivationManager.motivation = RMMotivation_SocialDrive;
    if (location == RMTouchLocationLeftEye || location == RMTouchLocationRightEye) {
        if (self.rapidEyePokeCount >= minimumRapidEyePokeCountToGetAngry) {
            // If the user pokes rapid enough, get angry
            self.rapidEyePokeCount = 0;
            self.Romo.character.expression = RMCharacterExpressionAngry;
        } else {
            // Increment the poke count, but fire a timer to quickly decrement it after a brief pause
            self.rapidEyePokeCount++;
            
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(rapidEyePokeCountDecrementDelay * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                self.rapidEyePokeCount--;
            });
        }
    } else {
        // If the poke isn't on Romo's eye, only some of the time, react to it
        BOOL creatureHasCustomPokeReaction = (self.chapter >=2 && self.chapterProgress > kPokeMission);
        if (creatureHasCustomPokeReaction && randFloat() < 0.10) {
            [RMMissionRuntime runUserTrainedAction:RMUserTrainedActionPoke
                                            onRomo:self.Romo
                                        completion:nil];
        }
    }
}

#pragma mark - Helpers
//------------------------------------------------------------------------------
- (RMCharacterExpression)randomExpression:(NSArray *)expressions
{
    return (RMCharacterExpression)[expressions[arc4random() % expressions.count] intValue];
}

//------------------------------------------------------------------------------
- (void)say:(NSString *)say
{
    [self.Romo.voice say:say withStyle:RMVoiceStyleSLS autoDismiss:YES];
}

//------------------------------------------------------------------------------
- (void)doSleepyTick
{
    if (currentTime() - self.lastFacePromptedSleepyTick > kSleepyTickTimeThreshold) {
        enableRomotions(self.idleMovementEnabled, self.Romo);
        RMCharacterExpression randomSleepyTick = [self randomExpression:@[@(RMCharacterExpressionSleepy),
                                                                          @(RMCharacterExpressionSneeze),
                                                                          @(RMCharacterExpressionYawn)]];
        [self.Romo.character setExpression:randomSleepyTick
                               withEmotion:RMCharacterEmotionSleeping];
        self.lastFacePromptedSleepyTick = currentTime();
    }
}

//------------------------------------------------------------------------------
- (BOOL)hasStoryElementForMission:(int)mission
                        inChapter:(RMChapter)chapter
{
    NSString *chapterFile = [[NSBundle mainBundle] pathForResource:[self filenameForMission:mission inChapter:chapter]
                                                            ofType:@"json"];
    return (chapterFile != nil);
}

//------------------------------------------------------------------------------
- (BOOL)hasStoryElementForScript:(NSString *)scriptName
{
    NSString *chapterFile = [[NSBundle mainBundle] pathForResource:scriptName
                                                            ofType:@"json"];
    return (chapterFile != nil);
}

//------------------------------------------------------------------------------
- (NSString *)filenameForMission:(int)mission
                       inChapter:(RMChapter)chapter
{
    NSMutableString *filename = [[NSMutableString alloc] initWithString:characterScriptPrefix];
    [filename appendString:[[NSNumber numberWithInt:chapter] stringValue]];
    [filename appendString:@"-"];
    [filename appendString:[[NSNumber numberWithInt:mission] stringValue]];
    return [NSString stringWithString:filename];
}

#ifdef CREATURE_DEBUG
#pragma mark - Debug
//------------------------------------------------------------------------------
- (void)initDebug
{
    // Build a view
    CGRect screenSize = [[UIScreen mainScreen] bounds];
    UIView *visionView = [[UIView alloc] initWithFrame:CGRectMake(screenSize.size.width - 138, screenSize.size.height - 168, 133, 163)];
    visionView.backgroundColor = [UIColor blackColor];
    visionView.layer.borderColor = [UIColor grayColor].CGColor;
    visionView.layer.borderWidth = 2.0f;
    visionView.contentMode = UIViewContentModeCenter;
    visionView.clipsToBounds = YES;
    visionView.layer.cornerRadius = 15.0f;
    
    [self.view addSubview:visionView];
    
    // Make sure the debug broker has our current vision object and add the output view
    [RMVisionDebugBroker shared].core = self.vision;
    [RMVisionDebugBroker shared].showFPS = YES;
    [[RMVisionDebugBroker shared] addOutputView:visionView];
}
#endif

#ifdef DEBUG
- (void)handleDebugPanGesture:(UIPanGestureRecognizer *)gesture
{
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            break;
            
        case UIGestureRecognizerStateChanged: {
            CGPoint velocity = [gesture velocityInView:gesture.view];
            
            if (velocity.y < -500) {
                // This nonsense cancels the gesture from triggering further
                gesture.enabled = NO;
                gesture.enabled = YES;
                
                RMInteractionScriptSelectorViewController *controller =
                [[RMInteractionScriptSelectorViewController alloc] initWithCompletion:^(BOOL success, NSDictionary *script) {
                    [self dismissViewControllerAnimated:YES completion:^{
                        if (success) {
                            RMInteractionScriptRuntime *runtime = [[RMInteractionScriptRuntime alloc] initWithScript:script];
                            [((RMAppDelegate *)[UIApplication sharedApplication].delegate) pushRobotController:runtime];
                            
                            [runtime setCompletion:^(BOOL aBool) {
                                [((RMAppDelegate *)[UIApplication sharedApplication].delegate) popRobotController];
                            }];
                        }
                    }];
                }];
                
                [self presentViewController:controller animated:YES completion:^{}];
            }
        } break;
            
        default:
            break;
    }
}
#endif

#pragma mark - UI Button Handlers
//------------------------------------------------------------------------------
- (void)userDidSelectOptionAtIndex:(int)optionIndex forVoice:(RMVoice *)voice
{
    [self.Romo.voice dismiss];
    
    if (optionIndex == 1) {
        RMMission *motivatedMission = self.currentMotivation[@"mission"];
        RMChapter motivatedChapter = motivatedMission ? motivatedMission.chapter : [self.currentMotivation[@"chapter"] intValue];
        
        RMRobotController *destination = nil;
        
        
        
        RMChapterStatus newestChapterStatus = [[RMProgressManager sharedInstance] statusForChapter:motivatedChapter];
        if ([[RMProgressManager sharedInstance].chapters containsObject:@(motivatedChapter)]) {
            BOOL isChapterNewlyUnlocked = (newestChapterStatus == RMChapterStatusSeenCutscene) || (newestChapterStatus == RMChapterStatusNew);
            if (isChapterNewlyUnlocked) {
                // If the user just unlocked this chapter, ensure that they see the unlock sequence
                destination = [[RMMissionRobotController alloc] init];
            }
        }
        
        if (motivatedMission) {
            // If we're playing a Mission, dive right into it
            destination = [[RMMissionRobotController alloc] initWithMission:motivatedMission];
        } else if (motivatedChapter == RMChapterTheLab) {
            // If we're playing The Lab, start there
            destination = [[RMMissionRobotController alloc] initWithMission:[[RMSandboxMission alloc] initWithChapter:RMChapterTheLab index:0]];
        } else {
            // Otherwise, we're playing with a Comet Activty
            switch (motivatedChapter) {
                case RMCometFavoriteColor: {
                    RMFavoriteColorRobotController *favoriteColor = [[RMFavoriteColorRobotController alloc] init];
                    favoriteColor.delegate = self;
                    destination = favoriteColor;
                    break;
                }
                    
                case RMCometChase: {
                    RMChaseRobotController *chase = [[RMChaseRobotController alloc] init];
                    chase.delegate = self;
                    destination = chase;
                    break;
                }
                    
                case RMCometLineFollow: {
                    RMLineFollowRobotController *lineFollow = [[RMLineFollowRobotController alloc] init];
                    lineFollow.delegate = self;
                    destination = lineFollow;
                    break;
                }
                    
                default: break;
            }
        }
        
        [((RMAppDelegate *)[UIApplication sharedApplication].delegate) pushRobotController:destination];
        
#ifdef SKIP_MISSION_PASS
        double delayInSeconds = 1.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            RMMission *mission = [[RMMission alloc] initWithChapter:self.chapter index:(self.chapterProgress+1)];
            mission.status = RMMissionStatusThreeStar;
            
            for (RMUnlockable *unlockable in mission.unlockables) {
                [[RMProgressManager sharedInstance] achieveUnlockable:unlockable];
            }
            [[RMProgressManager sharedInstance] setStatus:RMMissionStatusThreeStar
                                      forMissionInChapter:self.chapter
                                                    index:(self.chapterProgress+1)];
            
            RMCreatureRobotController *creatureController;
            switch (self.chapter) {
                case RMChapterOne:
                    creatureController = [[RMJuvenileCreatureRobotController alloc] init];
                    break;
                case RMChapterTwo:
                    creatureController = [[RMMatureCreatureRobotController alloc] init];
                    break;
                default:
                    break;
            }
            ((RMAppDelegate *)[UIApplication sharedApplication].delegate).robotController = creatureController;
            
        });
#endif
    } else {
        RMMission *motivatedMission = self.currentMotivation[@"mission"];
        if (motivatedMission.chapter == RMChapterOne && motivatedMission.index == 1) {
            // If this is the first mission, dsiplay some more information
            self.Romo.character.expression = RMCharacterExpressionLetDown;
            self.attentive = NO;
            
            // Only say something some of the time
            BOOL shouldSaySomething = randFloat() < 0.75;
            if (shouldSaySomething) {
                NSArray *prompts = @[
                                     NSLocalizedString(@"Mission-Plea-1", @"Please?!"),
                                     [NSString stringWithFormat:NSLocalizedString(@"Mission-Plea-2", @"C'mon, %@!"), [[RMRomoMemory sharedInstance] knowledgeForKey:@"userName"]],
                                     NSLocalizedString(@"Mission-Plea-3", @"But I don't know\nhow to!"),
                                     NSLocalizedString(@"Mission-Plea-4",  @"How am I supposed to\nexplore Earth?"),
                                     NSLocalizedString(@"Mission-Plea-5",  @"How am I supposed to\nexplore Earth?"),
                                     NSLocalizedString(@"Mission-Plea-6",  @"But that's why\nI traveled here!")
                                     ];
                int index = arc4random() % prompts.count;
                [self.Romo.voice say:prompts[index] withStyle:RMVoiceStyleLLS autoDismiss:NO];
            }
            
            double delayInSeconds = 3.5;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self.Romo.voice dismiss];
                self.attentive = YES;
            });
        }
    }
}

#pragma mark - Story progression
//------------------------------------------------------------------------------
- (void)revealStoryElementInScript:(NSString *)scriptFile
{
    NSString *chapterFile = [[NSBundle mainBundle] pathForResource:scriptFile
                                                            ofType:@"json"];
    RMInteractionScriptRuntime *script = [[RMInteractionScriptRuntime alloc] initWithJSONPath:chapterFile];
    
    if (script) {
        // Default completion (pops the RMInteractionScriptRuntime, returning here
        void (^completion)(BOOL) = ^(BOOL finished) {
            self.currentStoryElementHasBeenRevealed = YES;
            [((RMAppDelegate *)[UIApplication sharedApplication].delegate) popRobotController];
        };
        
        script.completion = completion;
        [((RMAppDelegate *)[UIApplication sharedApplication].delegate) pushRobotController:script];
    }
}

//------------------------------------------------------------------------------
- (void)setCurrentStoryElementHasBeenRevealed:(BOOL)currentStoryElementHasBeenRevealed
{
    if (_currentStoryElementHasBeenRevealed != currentStoryElementHasBeenRevealed) {
        _currentStoryElementHasBeenRevealed = currentStoryElementHasBeenRevealed;
        if (currentStoryElementHasBeenRevealed) {
            if ([self hasStoryElementForScript:self.currentStoryElement]) {
                [[RMProgressManager sharedInstance] updateStoryElement:self.currentStoryElement
                                                            withStatus:RMStoryStatusRevealed];
            }
        }
    }
}

//------------------------------------------------------------------------------
- (BOOL)creatureCanDrive
{
    return (self.chapter > RMChapterOne || (self.chapterProgress >= kCanDriveMission));
}

//------------------------------------------------------------------------------
- (BOOL)creatureCanTilt
{
    return (self.chapter > RMChapterOne || (self.chapterProgress >= kCanTiltMission));
}

//------------------------------------------------------------------------------
- (BOOL)creatureCanTurn
{
    return (self.chapter > RMChapterOne || (self.chapterProgress >= kCanTurnMission));
}

//------------------------------------------------------------------------------
- (BOOL)creatureKnowsRomotionTango
{
    return (self.chapter > RMChapterOne || (self.chapterProgress >= kRomotionTangoMission));
}

//------------------------------------------------------------------------------
- (BOOL)creatureShouldFartOnShake
{
    return (self.chapter == RMChapterTwo && self.chapterProgress >= kFartOnShakeMission) ||
           (self.chapter > RMChapterTwo && self.chapter != RMCometFavoriteColor);
    // TODO - This is hacky for now, but we're gonna add a helper macro soon.
}

//------------------------------------------------------------------------------
- (BOOL)creatureShouldReactToPickUpPutDown
{
    return (self.chapter == RMChapterTwo && self.chapterProgress >= kPickUpPutDownMission) ||
           (self.chapter > RMChapterTwo && self.chapter != RMCometFavoriteColor);
}

//------------------------------------------------------------------------------
- (BOOL)creatureDetectsFaces
{
    return (self.chapter == RMChapterTwo && self.chapterProgress >= kReactToFacesMission) ||
           (self.chapter > RMChapterTwo && self.chapter != RMCometFavoriteColor);
}

//------------------------------------------------------------------------------
- (BOOL)creatureRespondsToLoudSounds
{
    return (self.chapter == RMChapterThree && self.chapterProgress >= kLoudSoundsMission) ||
    (self.chapter > RMChapterThree && self.chapter != RMCometFavoriteColor && self.chapter != RMCometChase);
}

//------------------------------------------------------------------------------
- (BOOL)creatureDetectsMotion
{
    return (self.chapter == RMChapterThree && self.chapterProgress >= kDetectMotionMission) ||
    (self.chapter > RMChapterThree && self.chapter != RMCometFavoriteColor && self.chapter != RMCometChase);
}

//------------------------------------------------------------------------------
- (void)disableRomotionsIfPickedUp
{
    if (self.isPickedUp) {
        enableRomotions(NO, self.Romo);
    } else {
        enableRomotions(self.idleMovementEnabled, self.Romo);
    }
}

#pragma mark - Behavioral helpers

//------------------------------------------------------------------------------
- (void)_tiltUpAndDown:(int)numTimes
             withAngle:(int)angle
{
    self.numTiltCommands = numTimes;
    self.numCurrentTiltCommand = 1;
    self.lastTiltCommand = angle;
    
    [self _executeTilt];
}

//------------------------------------------------------------------------------
- (void)_executeTilt
{
    if (self.isActive && self.Romo.RomoCanDrive && self.robot) {
        if (self.Romo.RomoCanLook) {
            if (self.lastTiltCommand > 0) {
                [self.Romo.character lookAtPoint:RMPoint3DMake(0, -.8, 0.6) animated:YES];
            } else {
                [self.Romo.character lookAtPoint:RMPoint3DMake(0, .8, 0.6) animated:YES];
            }
        }
        [self.robot tiltByAngle:self.lastTiltCommand
                     completion:^(BOOL success) {
                         [self.robot stopTilting];
                         self.numCurrentTiltCommand++;
                         if (self.isActive && (self.numCurrentTiltCommand <= self.numTiltCommands)) {
                             self.lastTiltCommand *= -1;
                             [self _executeTilt];
                         } else {
                             if (self.Romo.RomoCanLook) {
                                 [self.Romo.character lookAtDefault];
                             }
                             self.tilting = NO;
                         }
                     }];
    }
}

//------------------------------------------------------------------------------
- (void)_moveBackAndForward:(int)numTimes
                  withSpeed:(float)speed
{
    self.numMoveCommands = numTimes;
    self.numCurrentMoveCommand = 1;
    self.lastMoveCommand = speed;
    
    [self _executeMoves];
}

//------------------------------------------------------------------------------
- (void)_executeMoves
{
    if (self.isActive && self.Romo.RomoCanDrive) {
        if (self.lastMoveCommand > 0) {
            [self.robot driveForwardWithSpeed:self.lastMoveCommand];
        } else {
            [self.robot driveBackwardWithSpeed:self.lastMoveCommand*-1];
        }
        
        float stepTime = CLAMP(0.1, randFloat(), 0.3);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(stepTime * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            self.numCurrentMoveCommand++;
            if (self.numCurrentMoveCommand <= self.numMoveCommands) {
                self.lastMoveCommand *= -1;
                [self _executeMoves];
            } else {
                enableRomotions(self.idleMovementEnabled, self.Romo);
                NSArray *random = @[@(RMCharacterExpressionExcited),
                                    @(RMCharacterExpressionHappy),
                                    @(RMCharacterExpressionLaugh),
                                    @(RMCharacterExpressionChuckle),
                                    @(RMCharacterExpressionProud)];
                
                [self.Romo.character setExpression:[self randomExpression:random]
                                       withEmotion:RMCharacterEmotionHappy];
            }
        });
    }
}

//------------------------------------------------------------------------------
- (void)_rotate:(int)numTimes
      withAngle:(int)angle
{
    self.numTurnCommands = numTimes;
    self.numCurrentTurnCommand = 1;
    self.lastTurnCommand = angle;
    
    [self _executeTurn];
}

//------------------------------------------------------------------------------
- (void)_executeTurn
{
    if (self.isActive && self.Romo.RomoCanDrive && self.robot) {
        if (!self.tilting && self.Romo.RomoCanLook) {
            if (self.lastTurnCommand > 0) {
                [self.Romo.character lookAtPoint:RMPoint3DMake(0.8, 0, 0.6) animated:YES];
            } else {
                [self.Romo.character lookAtPoint:RMPoint3DMake(-0.8, 0, 0.6) animated:YES];
            }
        }
        [self.robot turnByAngle:self.lastTurnCommand
                     withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                finishingAction:RMCoreTurnFinishingActionStopDriving
                     completion:^(BOOL success, float heading) {
                         self.numCurrentTurnCommand++;
                         if (self.isActive && (self.numCurrentTurnCommand <= self.numTurnCommands)) {
                             self.lastTurnCommand *= -1;
                             [self _executeTurn];
                         } else {
                             if (!self.tilting && self.Romo.RomoCanLook) {
                                 [self.Romo.character lookAtDefault];
                             }
                             enableRomotions(self.idleMovementEnabled, self.Romo);
                             NSArray *random = @[@(RMCharacterExpressionExcited),
                                                 @(RMCharacterExpressionHappy),
                                                 @(RMCharacterExpressionLaugh),
                                                 @(RMCharacterExpressionChuckle),
                                                 @(RMCharacterExpressionProud)];
                             
                             [self.Romo.character setExpression:[self randomExpression:random]
                                                    withEmotion:RMCharacterEmotionHappy];
                         }
                     }];
    }
}

@end
