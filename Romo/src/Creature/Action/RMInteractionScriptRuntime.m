//
//  RMInteractionScriptRuntime.m
//  Romo
//
//  Created on 8/14/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import "RMInteractionScriptRuntime.h"

#import <Romo/RMCoreRobot_Internal.h>
#import <Romo/RMVision.h>

#import "RMDockingRequiredVC.h"
#import "RMRomoMemory.h"
#import "RMMissionRuntime.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"
#import "UITextField+Validator.h"
#import "UIView+Additions.h"
#import "RMGradientLabel.h"

#import "RMProgressManager.h"
#import "RMCutscene.h"
#import "RMFreezeDanceBehavior.h"
#import "RMMusicConstants.h"
#import "RMRealtimeAudio.h"


#import <CocoaLumberjack/DDLog.h>
#import <Romo/RMMath.h>

#define kAutoProgressTimeout 20.0

typedef enum {
    RMInteractionScriptState_WaitingForCondition,
    RMInteractionScriptState_ExecutingActions,
    RMInteractionScriptState_WaitingForInteraction,
    /** If the controller starts up without a robot */
    RMInteractionScriptState_WaitingForDockToStart,
    RMInteractionScriptState_WaitingForExpressionBeforeStarting,
    RMInteractionScriptState_None
} RMInteractionScriptState;

static const int kPortaitKeyboardHeight = 216;

//static const int kButtonPadding = 20;

@interface RMInteractionScriptRuntime () <RMDockingRequiredVCDelegate, RMVoiceDelegate, UITextFieldDelegate>

// Store a pointer to the robot object and vision
@property (nonatomic, weak) RMCoreRobotRomo3 *robot;

// Storage for the script, blocks, and actions
@property (nonatomic, strong) NSDictionary *script;
@property (nonatomic, strong) NSArray *blocks;
@property (nonatomic, strong) NSArray *actions;

// Counters for total blocks/actions and current block/action indeces
@property (nonatomic) NSInteger numberOfBlocks;
@property (nonatomic) NSInteger blockNumber;

@property (nonatomic) NSInteger numberOfActionsInBlock;
@property (nonatomic) NSInteger actionNumber;

// Storage for if we're executing an action or if the block's condition has been met
@property (nonatomic) BOOL executingAction;
@property (nonatomic) BOOL conditionMet;
@property (nonatomic) BOOL hasExitCondition;
@property (nonatomic, getter=isPaused) BOOL paused;
@property (nonatomic) RMInteractionScriptState state;
@property (nonatomic, strong) NSTimer *autoProgressTimer;

// Faces
@property (nonatomic) BOOL waitingForFace;
@property (nonatomic) BOOL waitingForFaceDisappear;
@property (nonatomic, strong) NSTimer *lookTimer;

// Pokes / touches
@property (nonatomic) BOOL waitingForPokes;
@property (nonatomic) BOOL waitingForTouch;
@property (nonatomic) RMTouchLocation touchEventCondition;

@property (nonatomic) BOOL talking;
@property (atomic, getter=isTalkingAndExpressing) BOOL talkingAndExpressing;
@property (nonatomic) BOOL askingQuestion;
@property (atomic) BOOL talkingFinished;
@property (atomic) BOOL expressingFinished;
@property (nonatomic) BOOL scriptIsFinished;

// Docks / Undocks
@property (nonatomic) BOOL waitingForDock;
@property (nonatomic) BOOL waitingForUndock;

// Pick up / Put down
@property (nonatomic) BOOL waitingForPickedUp;
@property (nonatomic) BOOL waitingForPutDown;
@property (nonatomic) BOOL waitingForShake;

// Loud sounds / Clap
@property (nonatomic) BOOL waitingForLoudSound;
@property (nonatomic) BOOL waitingForClap;

// Trained actions
@property (nonatomic) BOOL executingBlockingBehavior;

// Questions / storage
@property (nonatomic, strong) NSMutableArray *lastChoices;
@property (nonatomic, strong) NSString *lastQuestion;
@property (nonatomic, strong) NSString *lastQuestionKey;
@property (nonatomic, strong) NSString *lastFreeInput;
@property (nonatomic, strong) UITextField *textInputField;

@property (nonatomic, strong) RMCutscene *cutscene;

- (void)addAndAnimateView:(UIView *)view afterRomoSaysMessage:(NSString *)message;
- (void)removeAndAnimateView:(UIView *)view afterRomoSaysMessage:(NSString *)message completion:(void (^)(BOOL finished))completion;
- (NSUInteger)numberOfLinesInString:(NSString *)string;

@end

@implementation RMInteractionScriptRuntime

#pragma mark - Initialization / Shutdown
//------------------------------------------------------------------------------
- (id)initWithScript:(NSDictionary *)script
{
    self = [super init];
    if (self) {
        _script = script[@"script"];
        _scriptIsFinished = NO;
        _lastChoices = [[NSMutableArray alloc] init];
        _lastQuestionKey = nil;
        _state = RMInteractionScriptState_None;
        _touchEventCondition = RMTouchLocationNone;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appEnteredBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appEnteredForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

//------------------------------------------------------------------------------
-(id)initWithJSON:(NSString *)json
{
    NSError *error;
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                                   options:0
                                                                     error:&error];
    if (error) {
        DDLogVerbose(@"Error parsing JSON file");
        return nil;
    } else {
        return [self initWithScript:jsonDictionary];
    }
}

//------------------------------------------------------------------------------
-(id)initWithJSONPath:(NSString *)path
{
    NSError *error;
    NSString* content = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
    if (error) {
        DDLogVerbose(@"Error finding JSON file at path: %@", path);
        return nil;
    } else {
        return [self initWithJSON:content];
    }
}

//------------------------------------------------------------------------------
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//------------------------------------------------------------------------------
- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    
    if (!self.script) {
        DDLogVerbose(@"ERROR: No script loaded in %@", NSStringFromClass(self.class));
        if (self.completion) {
            self.completion(NO);
        }
        return;
    }
    
    // International keyboards have varying heights from English
    // So register a notification so that we can reposition the
    // Romo face when the keyboard changes height
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    
    // Get vision and speech events
    self.Romo.voice.delegate = self;
    self.Romo.voice.character = self.Romo.character;
    
    // Initialize robot to use
    if ([self.Romo.robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.robot = (RMCoreRobotRomo3 *)self.Romo.robot;
    }
    // Set Romo to disable wakefulness (don't want outside actions interrupting us!)
    self.Romo.vitals.wakefulnessEnabled = NO;
    enableRomotions(YES, self.Romo);
    
    // Check to see if pick up and put down is present in script,
    // if it is, then activate that functionality
    // Also check on vision stuff
    BOOL needsEquilibrioception = NO;
    BOOL needsFaceVisionModule = NO;
    BOOL needsMotionVisionModule = NO;
    BOOL needsLoudSoundModule = NO;
    
    NSArray *blocks = self.script[@"blocks"];
    for (int i=0; i < blocks.count; i++) {
        if (blocks[i][@"condition"][@"name"]) {
            if ([blocks[i][@"condition"][@"name"] isEqualToString:@"pickedup"]
                || [blocks[i][@"condition"][@"name"] isEqualToString:@"putdown"]
                || [blocks[i][@"condition"][@"name"] isEqualToString:@"shake"]) {
                needsEquilibrioception = YES;
            }
            if ([blocks[i][@"condition"][@"name"] isEqualToString:@"face"]) {
                needsFaceVisionModule = YES;
            }
            if ([blocks[i][@"condition"][@"name"] isEqualToString:@"loudsound"]
                || [blocks[i][@"condition"][@"name"] isEqualToString:@"clap"]) {
                needsLoudSoundModule = YES;
            }
        }
    }
    
    // Check for motion
    if ([self _scriptContainsKeyword:@"freezedance"]) {
        needsMotionVisionModule = YES;
    }
    
    if ([self _scriptContainsKeyword:@"synth"]) {
        [RMRealtimeAudio sharedInstance].output = YES;
        [RMRealtimeAudio sharedInstance].synth.synthType = RMSynthWaveform_Square;
        [RMRealtimeAudio sharedInstance].synth.effectsEnabled = YES;
    }
    
    if (needsLoudSoundModule) {
        self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityLoudSound, self.Romo.activeFunctionalities);
    }
    
    if (needsEquilibrioception) {
        self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityEquilibrioception, self.Romo.activeFunctionalities);
    }
    
    if (needsFaceVisionModule || needsMotionVisionModule) {
        self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
    }
    if (needsFaceVisionModule) {
        [self.Romo.vision activateModuleWithName:RMVisionModule_FaceDetection];
    }
#ifdef INTERACTION_SCRIPT_DEBUG
    // Get name
    NSString *name = self.script[@"name"];
    DDLogVerbose(@"Running Script: %@\n", name);
    if (isFunctionalityActive(RMRomoFunctionalityEquilibrioception, self.Romo.activeFunctionalities)) {
        DDLogVerbose(@"Equilibrioception Enabled");
    }
#endif
    
#ifdef DEBUG
    UITapGestureRecognizer *threeFingerTripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                           action:@selector(_finishScript)];
    threeFingerTripleTap.numberOfTouchesRequired = 3;
    threeFingerTripleTap.numberOfTapsRequired = 3;
    [self.view addGestureRecognizer:threeFingerTripleTap];
#endif
    
    self.blocks = self.script[@"blocks"];
    self.numberOfBlocks = [self.blocks count];
    self.blockNumber = 0;
    
    [self start];
}

//------------------------------------------------------------------------------
- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    
    if ([self _scriptContainsKeyword:@"synth"]) {
        [RMRealtimeAudio sharedInstance].output = NO;
    }
    [self.robot.LEDs setSolidWithBrightness:1.0];
    
    [self.autoProgressTimer invalidate];
    [self.lookTimer invalidate];
    
    self.Romo.voice.character = nil;
    self.Romo.voice.delegate = nil;
    
    // OK Romo, you can have your sleepz soon.
    self.Romo.vitals.wakefulnessEnabled = YES;
    
    // Remove keyboard notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
}

- (RMRomoFunctionalities)initiallyActiveFunctionalities
{
    return RMRomoFunctionalityCharacter;
}

- (RMRomoInterruptions)initiallyAllowedInterruptions
{
    return RMRomoInterruptionNone;
}

- (NSSet *)initiallyActiveVisionModules
{
    return nil;
}

- (void)start
{
    if (!self.Romo.robot) {
        self.state = RMInteractionScriptState_WaitingForDockToStart;
        [self robotDidDisconnect:nil];
    } else if (self.Romo.character.expression) {
        self.state = RMInteractionScriptState_WaitingForExpressionBeforeStarting;
    } else {
        [self _executeBlock:self.blocks[self.blockNumber]];
    }
}

#pragma mark - Connection / Disconnection
//------------------------------------------------------------------------------
- (void)robotDidConnect:(RMCoreRobot *)robot
{
    if ([self.Romo.robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.robot = (RMCoreRobotRomo3 *)self.Romo.robot;
    }
    
    if (self.waitingForDock) {
        self.conditionMet = YES;
        self.waitingForDock = NO;
    }
}

//------------------------------------------------------------------------------
- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (self.waitingForUndock) {
        self.conditionMet = YES;
        self.waitingForUndock = NO;
    } else {
        self.paused = YES;
        
        RMDockingRequiredVC *dockingRequiredVC = [[RMDockingRequiredVC alloc] init];
        dockingRequiredVC.delegate = self;
        dockingRequiredVC.showsPurchaseButton = NO;
        dockingRequiredVC.showsDismissButton = NO;
        
        [self presentViewController:dockingRequiredVC animated:YES
                         completion:^{
                             if (self.robot) {
                                 [self dockingRequiredVCDidDock:dockingRequiredVC];
                             }
                         }];
    }
}

#pragma mark - RMDockingRequiredVCDelegate
//------------------------------------------------------------------------------
- (void)dockingRequiredVCDidDismiss:(RMDockingRequiredVC *)dockingRequiredVC
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

//------------------------------------------------------------------------------
- (void)dockingRequiredVCDidDock:(RMDockingRequiredVC *)dockingRequiredVC
{
    if (!dockingRequiredVC.isBeingPresented) {
        [self dismissViewControllerAnimated:YES completion:nil];
        
        self.paused = NO;
    }
}

#pragma mark - Backgrounding / Foregrounding events
//------------------------------------------------------------------------------
- (void)appEnteredBackground:(NSNotification *)notification
{
    self.paused = YES;
}

//------------------------------------------------------------------------------
- (void)appEnteredForeground:(NSNotification *)notification
{
    self.paused = NO;
}

#pragma mark - Blocks
//------------------------------------------------------------------------------
- (void)_executeBlock:(NSDictionary *)block
{
    self.state = RMInteractionScriptState_WaitingForCondition;
    // Dismiss current text
    [self.Romo.voice dismiss];
    
    // Condition (required: name, optional: args)
    NSDictionary *cond = block[@"condition"];
    self.actions = block[@"actions"];
    self.actionNumber = 0;
    self.numberOfActionsInBlock = self.actions.count;
    if (cond) {
        NSString *conditionType = cond[@"name"];
        if ([conditionType isEqualToString:@"none"]) {
            self.conditionMet = YES;
        } else if ([conditionType isEqualToString:@"wait"]) {
            NSArray *args = cond[@"args"];
            assert(args.count == 1);
            if (args) {
                double delayInSeconds = [args[0] floatValue];
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    self.conditionMet = YES;
                });
            }
        } else if ([conditionType isEqualToString:@"face"]) {
            NSArray *args = cond[@"args"];
            assert(args.count == 1);
            if (args) {
                if ([args[0] isEqualToString:@"appear"]) {
                    self.waitingForFace = YES;
                } else if ([args[0] isEqualToString:@"disappear"]) {
                    self.waitingForFaceDisappear = YES;
                }
            }
        } else if ([conditionType isEqualToString:@"poke"]) {
            self.waitingForPokes = YES;
            NSArray *args = cond[@"args"];
            if (args) {
                NSString *pokeLocation = args[0];
                
                self.touchEventCondition = [self touchLocationforString:pokeLocation];
                
            } else {
                self.touchEventCondition = RMTouchLocationNone;
            }
        } else if ([conditionType isEqualToString:@"tickle"]) {
            NSArray *args = cond[@"args"];
            assert(args.count == 1);
            if (args) {
                NSString *tickleLocation = args[0];
                self.waitingForTouch = YES;
                self.touchEventCondition = [self touchLocationforString:tickleLocation];
            }
        } else if ([conditionType isEqualToString:@"store-id"]) {
            NSArray *args = cond[@"args"];
            assert(args.count >= 1);
            if (args) {
                if (args.count == 2) {
                    // Multiple choice
                    NSString *key = args[0];
                    NSString *willEvalIfEquals = args[1];
                    if ([[[RMRomoMemory sharedInstance] knowledgeForKey:key] isEqualToString:willEvalIfEquals]) {
                        self.conditionMet = YES;
                    } else {
                        // Skip the block and call the block completion
                        [self finishedBlock];
                    }
                } else {
                    // Keyboard input
                    self.conditionMet = YES;
                }
            }
        } else if ([conditionType isEqualToString:@"dock"]) {
            NSArray *args = cond[@"args"];
            assert(args.count >= 1);
            if (args) {
                if ([args[0] intValue] == 1) {
                    // wait until dock
                    self.waitingForDock = YES;
                } else {
                    // wait until undock
                    self.waitingForUndock = YES;
                }
            }
        } else if ([conditionType isEqualToString:@"pickedup"]) {
            self.waitingForPickedUp = YES;
        } else if ([conditionType isEqualToString:@"putdown"]) {
            self.waitingForPutDown = YES;
        } else if ([conditionType isEqualToString:@"loudsound"]) {
            self.waitingForLoudSound = YES;
        } else if ([conditionType isEqualToString:@"clap"]) {
            self.waitingForClap = YES;
        }else {
            if (self.completion) {
                self.completion(NO);
            }
            NSLog(@"ERROR: Invalid Condition: %@", conditionType);
        }
    }
    
    // Check whehter the condition is on enter (default) or exit
    if ([cond[@"on"] isEqualToString:@"exit"]) {
        self.hasExitCondition = YES;
        // execute the current block of actions immediately
        // but the hasExitCondition flag will prevent the flow from
        // going to the next block until the condition has been met
        [self executeActionBlock];
    }
}

//------------------------------------------------------------------------------
-(void)setConditionMet:(BOOL)conditionMet
{
    if (_conditionMet != conditionMet) {
        _conditionMet = conditionMet;
        
        if (conditionMet) {
            if (self.hasExitCondition) {
                self.hasExitCondition = NO;
                [self finishedBlock];
            } else {
                [self executeActionBlock];
            }
        }
    }
}

//------------------------------------------------------------------------------
- (void)setPaused:(BOOL)paused
{
    if (_paused != paused) {
        _paused = paused;
        if (paused) {
            [self.autoProgressTimer invalidate];
            [RMMissionRuntime stopRunning];
        } else {
            switch (self.state) {
                case RMInteractionScriptState_ExecutingActions:
                    if (self.actionNumber == self.numberOfActionsInBlock) {
                        if (!self.hasExitCondition) {
                            [self finishedBlock];
                        }
                    } else if (self.actionNumber < self.numberOfActionsInBlock) {
                        [self _executeAction:self.actions[self.actionNumber]];
                    }
                    break;
                case RMInteractionScriptState_WaitingForDockToStart:
                case RMInteractionScriptState_WaitingForExpressionBeforeStarting:
                    [self start];
                    break;
                case RMInteractionScriptState_WaitingForCondition:
                case RMInteractionScriptState_WaitingForInteraction:
                case RMInteractionScriptState_None:
                default:
                    break;
            }
        }
    }
}

//------------------------------------------------------------------------------
- (void)finishedBlock
{
#ifdef INTERACTION_SCRIPT_DEBUG
    DDLogVerbose(@"***Finished block %i.***",self.blockNumber);
#endif
    
    if (self.isPaused) {
        return;
    }
    
    self.conditionMet = NO;
    self.blockNumber++;
    if (self.blockNumber == self.numberOfBlocks) {
        [self _finishScript];
    } else {
        [self _executeBlock:self.blocks[self.blockNumber]];
    }
}

//------------------------------------------------------------------------------
- (void)_finishScript
{
#ifdef INTERACTION_SCRIPT_DEBUG
    DDLogVerbose(@"***Finished executing script.***");
#endif
    self.state = RMInteractionScriptState_None;
    self.scriptIsFinished = YES;
    self.Romo.voice.character = nil;
    self.Romo.voice.delegate = nil;
    if (self.completion) {
        self.completion(YES);
    }
}

#pragma mark - Actions
//------------------------------------------------------------------------------
- (void)_executeAction:(NSDictionary *)action
{
    if (self.paused) {
        return;
    }
    // Start a timer (in case anything gets stuck, the script still progresses)
    self.autoProgressTimer = [NSTimer scheduledTimerWithTimeInterval:kAutoProgressTimeout
                                                              target:self
                                                            selector:@selector(finishedAction)
                                                            userInfo:nil
                                                             repeats:NO];
    
    // We're about to execute an action! Set the flag and get the type
    self.executingAction = YES;
    NSString *actionType = action[@"name"];
    
    // Pull out any arguments
    NSArray *args = action[@"args"];
    
#ifdef INTERACTION_SCRIPT_DEBUG
    DDLogVerbose(@"\t\t-Executing action %d: %@", self.actionNumber, actionType);
    if (args) {
        [self _printArgs:args];
    }
#endif
    
    // Go through all the action types
    //--------------------------------
    // Expressions
    if ([actionType isEqualToString:@"expression"]) {
        assert(args.count >= 1);
        if (args.count >= 2 && [[[args lastObject] lowercaseString] isEqualToString:@"no"]) {
            enableRomotions(NO, self.Romo);
        } else {
            enableRomotions(YES, self.Romo);
        }
        self.Romo.character.expression = [RMCharacter mapReadableNameToExpression:args[0]];
    }
    // Expression -> Emotion
    else if ([actionType isEqualToString:@"expressionToEmotion"]) {
        assert(args.count >= 2);
        if (args.count >= 3 && [[[args lastObject] lowercaseString] isEqualToString:@"no"]) {
            enableRomotions(NO, self.Romo);
        } else {
            enableRomotions(YES, self.Romo);
        }
        
        RMCharacterEmotion desiredEmotion = [RMCharacter mapReadableNameToEmotion:args[1]];
        if (self.Romo.character.emotion != desiredEmotion) {
            [self.Romo.character setExpression:[RMCharacter mapReadableNameToExpression:args[0]]
                                   withEmotion:desiredEmotion];
        } else {
            self.Romo.character.expression = [RMCharacter mapReadableNameToExpression:args[0]];
        }
    }
    // Expression with text
    else if ([actionType isEqualToString:@"expressionWithText"]) {
        assert(args.count >= 2);
        enableRomotions(YES, self.Romo);
        
        RMCharacterExpression desiredExpression = [RMCharacter mapReadableNameToExpression:args[0]];
        RMCharacterEmotion desiredEmotion = self.Romo.character.emotion;
        NSString *stringToSay = args[1];
        
        if (args.count == 3) {
            desiredEmotion = [RMCharacter mapReadableNameToEmotion:args[1]];
            stringToSay = [args lastObject];
        } else if (args.count >= 4 && [[[args lastObject] lowercaseString] isEqualToString:@"no"]) {
            enableRomotions(NO, self.Romo);
            stringToSay = args[2];
        }
        
        self.talkingAndExpressing = YES;
        self.talkingFinished = NO;
        self.expressingFinished = NO;
        
        // Express dat
        if (self.Romo.character.emotion != desiredEmotion) {
            [self.Romo.character setExpression:desiredExpression
                                   withEmotion:desiredEmotion];
        } else {
            self.Romo.character.expression = desiredExpression;
        }
        
        BOOL autoDismiss = (args.count >= 4 && [args[3] isEqualToString:@"no dismiss"]) ? NO : YES;
        
        // Say dat without the mumble
        self.Romo.voice.muteMumbleSound = YES;
        [self sayText:[self formatString:stringToSay] withAutoDismiss:autoDismiss];
        
    }
    // Mumble with text
    else if ([actionType isEqualToString:@"mumbleWithText"]) {
        assert(args.count == 1);
        enableRomotions(YES, self.Romo);
        
        NSString *stringToSay = args[0];
        
        enableRomotions(NO, self.Romo);
        
        self.talkingAndExpressing = YES;
        self.talkingFinished = NO;
        self.expressingFinished = NO;
        
        self.Romo.voice.muteMumbleSound = YES;
        [self.Romo.character mumble];
        [self sayText:[self formatString:stringToSay] withAutoDismiss:YES];
    }
    // Mumble with text
    else if ([actionType isEqualToString:@"mumbleWithRandomTextFromList"]) {
        assert(args.count >= 1);
        
        NSInteger randomIndex = arc4random_uniform((uint32_t)args.count);
        NSString *randomString = args[randomIndex];
        assert(randomString != nil);
        
        enableRomotions(NO, self.Romo);
        
        self.talkingAndExpressing = YES;
        self.talkingFinished = NO;
        self.expressingFinished = NO;
        
        self.Romo.voice.muteMumbleSound = YES;
        [self.Romo.character mumble];
        [self sayText:[self formatString:randomString] withAutoDismiss:YES];
    }
    // Emotion
    else if ([actionType isEqualToString:@"emotion"]) {
        assert(args.count == 1);
        RMCharacterEmotion desiredEmotion = [RMCharacter mapReadableNameToEmotion:args[0]];
        if (self.Romo.character.emotion != desiredEmotion) {
            self.Romo.character.emotion = desiredEmotion;
        } else {
            [self finishedAction];
        }
    }
    // Look at something
    else if ([actionType isEqualToString:@"look"]) {
        assert(args.count >= 2);
        float zLoc = 0.5;
        if (args.count == 3) {
            zLoc = [args[2] floatValue];
        }
        [self.Romo.character lookAtPoint:RMPoint3DMake([args[0] floatValue],
                                                       [args[1] floatValue],
                                                       zLoc)
                                animated:YES];
        [self finishedAction];
    }
    // Just do a little mumble
    else if ([actionType isEqualToString:@"mumble"]) {
        self.Romo.voice.muteMumbleSound = NO;
        [self.Romo.character say:@"PICKLES"];
        
        [self finishedAction];
    }
    // Execute an action that was trained through a mission
    else if ([actionType isEqualToString:@"executeTrainedAction"]) {
        assert (args.count == 1);
        NSString *actionToExecute = args[0];
        self.executingBlockingBehavior = YES;
        
        void (^completion)(BOOL) = ^(BOOL finished) {
            if (finished) {
                [self blockingBehaviorDidFinish];
            }
        };
        RMUserTrainedAction trainedAction = [self _mapNameToTrainedAction:actionToExecute];
        if (trainedAction != RMUserTrainedActionInvalid) {
            [RMMissionRuntime runUserTrainedAction:trainedAction
                                            onRomo:self.Romo
                                        completion:completion];
        }
    }
    // Say something
    else if ([actionType isEqualToString:@"say"]) {
        assert(args.count >= 1);
        self.Romo.voice.muteMumbleSound = NO;
        BOOL autoDismiss = (args.count == 2 && [args[1] isEqualToString:@"no dismiss"]) ? NO : YES;
        [self sayText:[self formatString:args[0]] withAutoDismiss:autoDismiss];
    }
    // Say something from a list of possible phrases
    else if ([actionType isEqualToString:@"sayRandomFromList"]) {
        NSInteger numPossibilities = args.count;
        assert(numPossibilities >= 1);
        
        int randomIndex = arc4random_uniform((uint32_t)numPossibilities);
        NSString *randomString = args[randomIndex];
        
        assert(randomString != nil);
        
        self.Romo.voice.muteMumbleSound = NO;
        
        [self sayText:[self formatString:randomString] withAutoDismiss:YES];
    }
    // Ask question
    else if ([actionType isEqualToString:@"ask"]) {
        assert(args.count >= 1);
        self.state = RMInteractionScriptState_WaitingForInteraction;
        self.askingQuestion = YES;
        self.talking = NO;
        [self.autoProgressTimer invalidate];
        self.Romo.voice.muteMumbleSound = NO;
        
        // Get the store-id
        self.lastQuestionKey = action[@"store-id"];
        if (!self.lastQuestionKey) {
            DDLogVerbose(@"WARNING: no store-id with script question");
        }
        self.lastQuestion = [self formatString:args[0]];
        
        if (args.count > 2) {
            // Multiple choice
            NSInteger numChoices = args.count - 1;
            [self.lastChoices removeAllObjects];
            for (int i = 1; i <= numChoices; i++) {
                [self.lastChoices addObject:args[i]];
            }
            
            [self.Romo.voice ask:self.lastQuestion
                     withAnswers:self.lastChoices];
        } else {
            NSString *placeholder = [args lastObject];
            [self.Romo.voice say:self.lastQuestion withStyle:RMVoiceStyleSSS autoDismiss:NO];
            self.Romo.voice.bottom = self.view.height - self.textInputField.height;
            self.textInputField.placeholder = [[NSBundle mainBundle] localizedStringForKey:placeholder value:placeholder table:@"CharacterScripts"];
            self.textInputField.bottom = self.view.height;
            [self addAndAnimateView:self.textInputField afterRomoSaysMessage:self.lastQuestion];
        }
    }
    // Move the rover
    else if ([actionType isEqualToString:@"move"]) {
        assert(args.count >= 2);
        
        NSString *direction = [args[0] lowercaseString];
        float motorPower = [direction isEqualToString:@"backward"] ? -1.0 : 1.0;
        float duration = [args[1] floatValue];
        
        // If there's a third argument, use that as a scalar for power
        if (args.count > 2) {
            motorPower *= [[args lastObject] floatValue];
        }
        
        [self.robot driveForwardWithSpeed:motorPower];
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.robot stopDriving];
            [self finishedAction];
        });
    }
    // Turn the rover
    else if ([actionType isEqualToString:@"turn"]) {
        assert(args.count == 2);
        NSString *direction = [args[0] lowercaseString];
        float turnScalar = [direction isEqualToString:@"left"] ? 1.0 : -1.0;
        float amount = [[args lastObject] floatValue];
        if (self.robot && !self.robot.isSimulated && self.robot.isConnected) {
            [self.robot turnByAngle:amount*turnScalar
                         withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                    finishingAction:RMCoreTurnFinishingActionStopDriving
                         completion:^(BOOL success, float heading) {
                             [self finishedAction];
                         }];
        } else {
            [self finishedAction];
        }
    }
    // Spin the rover in place for a given amount of time
    else if ([actionType isEqualToString:@"spin"]) {
        assert(args.count == 2);
        NSString *direction = [args[0] lowercaseString];
        float amountOfTimeToSpin = [[args lastObject] floatValue];
        // Execute the spin
        if ([direction isEqualToString:@"left"]) {
            [self.robot driveWithLeftMotorPower:-1.0 rightMotorPower:1.0];
        } else {
            [self.robot driveWithLeftMotorPower:1.0 rightMotorPower:-1.0];
        }
        // Dispatch an action finisher to run at the right time.
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(amountOfTimeToSpin * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.robot stopAllMotion];
            [self finishedAction];
        });
    }
    // Differential Drive the motors
    else if ([actionType isEqualToString:@"tankdrive"]) {
        assert(args.count == 3);
        float leftPower = [args[0] floatValue];
        float rightPower = [args[1] floatValue];
        float duration = [[args lastObject] floatValue];
        [self.robot driveWithLeftMotorPower:leftPower rightMotorPower:rightPower];
        // Dispatch an action finisher to run at the right time.
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.robot stopAllMotion];
            [self finishedAction];
        });
    }
    // Tilt the device by a certain amount
    else if ([actionType isEqualToString:@"tilt"]) {
        assert(args.count == 2);
        NSString *direction = [args[0] lowercaseString];
        float angle = [[args lastObject] floatValue];
        float sign = [direction isEqualToString:@"down"] ? -1.0 : 1.0;
        if (self.robot && !self.robot.isSimulated && self.robot.isConnected) {
            [self.robot tiltByAngle:sign * angle
                         completion:^(BOOL success) {
                             [self.robot stopTilting];
                             [self finishedAction];
                         }];
        } else {
            [self finishedAction];
        }
    }
    // Tilt the device to a certain point
    else if ([actionType isEqualToString:@"tiltTo"]) {
        assert(args.count == 1);
        float angle = [args[0] floatValue];
        if (self.robot && !self.robot.isSimulated && self.robot.isConnected) {
            [self.robot tiltToAngle:angle
                         completion:^(BOOL success) {
                             [self.robot stopTilting];
                             [self finishedAction];
                         }];
        } else {
            [self finishedAction];
        }
    }
    // Set LED to a certain brightness
    else if ([actionType isEqualToString:@"LED"]) {
        assert(args.count == 1);
        float brightness = [args[0] floatValue];
        [self.robot.LEDs setSolidWithBrightness:brightness];
        [self finishedAction];
    }
    // Stop all motion
    else if ([actionType isEqualToString:@"stop"]) {
        [self.robot stopAllMotion];
        [self finishedAction];
    }
    // Take a picture
    else if ([actionType isEqualToString:@"takePicture"]) {
        // TODO - tell vision to save to internal data structure, not Photos
        self.Romo.character.rightEyeOpen = NO;
        self.Romo.activeFunctionalities = enableFunctionality(RMRomoFunctionalityVision, self.Romo.activeFunctionalities);
        [self.Romo.vision activateModuleWithName:RMVisionModule_TakePicture];
        
        double delayInSeconds = 1.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            self.Romo.character.rightEyeOpen = YES;
            [self finishedAction];
        });
        
    }
    // Wait for a certain amount of time
    else if ([actionType isEqualToString:@"wait"]) {
        assert(args.count == 1);
        float duration = [args[0] floatValue];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self finishedAction];
        });
    }
    // Saves a store-id
    else if ([actionType isEqualToString:@"setKnowledge"]) {
        self.Romo.character.rightEyeOpen = NO;
        assert(args.count == 2);
        if (args[0]) {
            [[RMRomoMemory sharedInstance] setKnowledge:args[1] forKey:args[0]];
        }
        [self finishedAction];
    }
    // Play video
    else if ([actionType isEqualToString:@"cutscene"]) {
        assert(args.count == 1);
        __weak RMInteractionScriptRuntime *weakSelf = self;
        [self.Romo.character removeFromSuperview];
        [self.cutscene playCutscene:[args[0] intValue] inView:self.view completion:^(BOOL finished) {
            weakSelf.cutscene = nil;
            [weakSelf.Romo.character addToSuperview:weakSelf.characterView];
            [weakSelf finishedAction];
        }];
    }
    // Shows a photo slideshow of capturedPhotos then clears out capturedPhotos
    else if ([actionType isEqualToString:@"slideshow"]) {
        [self showSlideshowWithCompletion:^{
            [[RMProgressManager sharedInstance].capturedPhotos removeAllObjects];
            [self finishedAction];
        }];
    }
    // Runs a custom behavior
    else if ([actionType isEqualToString:@"runBehavior"]) {
        assert(args.count == 1);
        NSString *desiredBehavior = [args[0] lowercaseString];
        if ([desiredBehavior isEqualToString:@"freezedance"]) {
            self.executingBlockingBehavior = YES; // Set flag that we're blocking
            
            // Set up behavior
            RMFreezeDanceBehavior *newBehavior = [[RMFreezeDanceBehavior alloc] initWithRomo:self.Romo];
            newBehavior.completion = ^(BOOL finished) {
                [self blockingBehaviorDidFinish];
            };
            
            // Start the behavior (it will stop after a timeout)
            [newBehavior start];
        }
    }
    // Plays a synth note and lights up the LED
    else if ([actionType isEqualToString:@"synth"]) {
        assert(args.count >= 1);
        RMMusicPitch pitch = [RMSynthesizer pitchForString:args[0]];
        RMMusicOctave octave = RMMusicOctave_5;
        if (args.count >= 2) {
            octave = [args[1] intValue];
        }
        [self.robot.LEDs setSolidWithBrightness:1.0];
        [RMRealtimeAudio sharedInstance].synth.frequency = [RMSynthesizer noteToFrequency:pitch inOctave:octave];
        [[RMRealtimeAudio sharedInstance].synth play];
        if (args.count == 3) {
            double delayInSeconds = [args[2] floatValue];
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self.robot.LEDs setSolidWithBrightness:0.3];
                [[RMRealtimeAudio sharedInstance].synth stop];
                [self finishedAction];
            });
        } else {
            [self finishedAction];
        }
    }
    else {
        NSLog(@"ERROR: Invalid Action: %@", actionType);
        if (self.completion) {
            self.completion(NO);
        }
        return;
    }
}

- (void)showSlideshowWithCompletion:(void (^)(void))completion
{
    [self.Romo.character lookAtPoint:RMPoint3DMake(0, 1.0, 0.0) animated:YES];
    [self showSlideshowFromIndex:0 completion:completion];
}

- (void)showSlideshowFromIndex:(int)index completion:(void (^)(void))completion
{
    static NSMutableArray *photoViews;
    
    NSArray *photos = [RMProgressManager sharedInstance].capturedPhotos;
    if (index < photos.count) {
        if (!photoViews) {
            photoViews = [NSMutableArray arrayWithCapacity:photos.count];
        }
        
        // A random amount to rotate the photo by
        float randomRotation = 0.2 * randFloat() * (index % 2 ? 1 : -1);
        
        // Position the photo just off screen...
        UIImageView *photoView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
        photoView.image = photos[index];
        photoView.contentMode = UIViewContentModeScaleAspectFill;
        photoView.clipsToBounds = YES;
        photoView.centerX = self.view.width / 2.0 + randFloat() * 20.0 - 10.0;
        photoView.top = self.view.height + 40.0;
        photoView.transform = CGAffineTransformMakeRotation(randomRotation);
        photoView.layer.borderColor = [UIColor whiteColor].CGColor;
        photoView.layer.borderWidth = 8.0;
        [photoViews addObject:photoView];
        [self.view addSubview:photoView];
        
        //...then animate it in like it's being tossed
        float delay = (index == 0) ? 0.0 : 3.0;
        [UIView animateWithDuration:0.65 delay:delay options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             float randomRotation = 0.2 * randFloat() * (index % 2 ? 1 : -1);
                             
                             photoView.transform = CGAffineTransformMakeRotation(randomRotation);
                             photoView.center = CGPointMake(self.view.width / 2.0 + randFloat(), self.view.height - 100.0);
                         } completion:^(BOOL finished) {
                             [self showSlideshowFromIndex:index+1 completion:completion];
                         }];
        
    } else {
        // When we're done, shoot them all off screen
        [UIView animateWithDuration:0.25 delay:3.0 options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             [photoViews enumerateObjectsUsingBlock:^(UIView *photoView, NSUInteger idx, BOOL *stop) {
                                 photoView.top = self.view.height + 40.0;
                             }];
                         } completion:^(BOOL finished) {
                             [photoViews enumerateObjectsUsingBlock:^(UIView *photoView, NSUInteger idx, BOOL *stop) {
                                 [photoView removeFromSuperview];
                             }];
                             photoViews = nil;
                             
                             [self.Romo.character lookAtDefault];
                             
                             if (completion) {
                                 completion();
                             }
                         }];
    }
}

//------------------------------------------------------------------------------
- (void)finishedAction
{
    if (self.executingBlockingBehavior) {
        return;
    }
    self.executingAction = NO;
    [self.autoProgressTimer invalidate];
    self.actionNumber++;
    if (self.actionNumber == self.numberOfActionsInBlock) {
        if (!self.hasExitCondition) {
            [self finishedBlock];
        }
    } else if (self.actionNumber < self.numberOfActionsInBlock) {
        [self _executeAction:self.actions[self.actionNumber]];
    }
}

#pragma mark - Helpers
//------------------------------------------------------------------------------
- (UITextField *)textInputField
{
    if (!_textInputField) {
        static const CGFloat buttonHeight = 54.0;
        CGRect frame = {0, 0, self.view.width, buttonHeight};
        _textInputField = [[UITextField alloc] initWithFrame:frame];
        _textInputField.autocorrectionType = UITextAutocorrectionTypeNo;
        _textInputField.returnKeyType = UIReturnKeyDone;
        _textInputField.background = [[UIImage imageNamed:@"romoVoiceBackdrop.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
        _textInputField.font = [UIFont fontWithSize:30.0];
        _textInputField.textColor = [UIColor whiteColor];
        _textInputField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        _textInputField.textAlignment = NSTextAlignmentCenter;
        _textInputField.delegate = self;
        _textInputField.accessibilityLabel = @"Input Field";
        _textInputField.isAccessibilityElement = YES;
    }
    
    return _textInputField;
}

//------------------------------------------------------------------------------
- (RMUserTrainedAction)_mapNameToTrainedAction:(NSString *)name
{
    // Check we have a string
    if (!name) {
        return RMUserTrainedActionInvalid;
    } else {
        // Convert string to lowercase and strip!
        name = [name lowercaseString];
        name = [name stringByReplacingOccurrencesOfString:@" " withString:@""];
        name = [name stringByReplacingOccurrencesOfString:@"_" withString:@""];
        name = [name stringByReplacingOccurrencesOfString:@"-" withString:@""];
    }
    
    // Do the mapping
    if ([name isEqualToString:@"driveinacircle"]) {
        return RMUserTrainedActionDriveInACircle;
    } else if ([name isEqualToString:@"driveinasquare"]) {
        return RMUserTrainedActionDriveInASquare;
    } else if ([name isEqualToString:@"romotiontango"]) {
        return RMUserTrainedActionRomotionTango;
    } else if ([name isEqualToString:@"romotiontangomusic"]) {
        return RMUserTrainedActionRomotionTangoWithMusic;
    } else if ([name isEqualToString:@"pickupresponse"]) {
        return RMUserTrainedActionPickedUp;
    } else if ([name isEqualToString:@"putdownresponse"]) {
        return RMUserTrainedActionPutDown;
    } else {
        return RMUserTrainedActionInvalid;
    }
}

//------------------------------------------------------------------------------
- (void)_printArgs:(NSArray *)args
{
#ifdef INTERACTION_SCRIPT_DEBUG
    if (args) {
        NSMutableString *argString = [[NSMutableString alloc] initWithString:@"\t\tArguments: ["];
        for (int i = 0; i < args.count; i++) {
            NSValue *arg = args[i];
            [argString appendFormat:@"%@", arg];
            if ( i != (args.count - 1) ) {
                [argString appendString:@", "];
            } else {
                [argString appendString:@"]"];
            }
        }
        DDLogVerbose(@"%@", argString);
    }
#endif
}

//------------------------------------------------------------------------------
- (BOOL)_scriptContainsKeyword:(NSString *)keyword
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.script
                                                       options:0
                                                         error:&error];
    if (!jsonData) {
        DDLogVerbose(@"Got an error: %@", error);
        return NO;
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        if ([jsonString rangeOfString:keyword].location != NSNotFound) {
            return YES;
        } else {
            return NO;
        }
    }
}

//------------------------------------------------------------------------------
- (void)setWaitingForFace:(BOOL)waitingForFace
{
    if (_waitingForFace != waitingForFace) {
        if (waitingForFace) {
            [self.Romo.character lookAtPoint:RMPoint3DMake(-1, 0, 1)
                                    animated:YES];
            self.lookTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
                                                              target:self
                                                            selector:@selector(lookOtherWay:)
                                                            userInfo:nil
                                                             repeats:YES];
        } else {
            [self.lookTimer invalidate];
            [self.Romo.character lookAtDefault];
        }
        _waitingForFace = waitingForFace;
    }
}

//------------------------------------------------------------------------------
- (void)lookOtherWay:(NSTimer *)timer
{
    if (self.Romo.character.gaze.x < 0) {
        [self.Romo.character lookAtPoint:RMPoint3DMake(1, 0, 1)
                                animated:YES];
    } else {
        [self.Romo.character lookAtPoint:RMPoint3DMake(-1, 0, 1)
                                animated:YES];
    }
}

//------------------------------------------------------------------------------
- (NSString *)formatString:(NSString *)string
{
    // Get localized version
    NSString *localizedLookupKey = [string stringByReplacingOccurrencesOfString:@"\n" withString:@"%n"];
    NSString *localString = [[NSBundle mainBundle] localizedStringForKey:localizedLookupKey
                                                                   value:string
                                                                   table:@"CharacterScripts"];
    NSString *formattedLocalString = [localString stringByReplacingOccurrencesOfString:@"%n" withString:@"\n"];
    
    NSMutableString *result = [[NSMutableString alloc] initWithString:formattedLocalString];
    // Check for instances of special strings to replace with Memory items
    NSString *startTokenFlag = @"${";
    NSString *endTokenFlag = @"}";
    
    BOOL hasMoreTokens = ([string rangeOfString:startTokenFlag].location != NSNotFound);
    NSRange rangeOfNextStartToken;
    NSRange rangeOfNextEndToken;
    
    while (hasMoreTokens) {
        rangeOfNextStartToken = [result rangeOfString:startTokenFlag];
        rangeOfNextEndToken = [result rangeOfString:endTokenFlag];
        NSUInteger indexOfStartToken = rangeOfNextStartToken.location;
        NSUInteger indexOfEndToken = rangeOfNextEndToken.location;
        hasMoreTokens = indexOfStartToken != NSNotFound || indexOfEndToken != NSNotFound;
        if (hasMoreTokens) {
            NSUInteger keyStartLocation = indexOfStartToken + startTokenFlag.length;
            NSUInteger keyLength = indexOfEndToken - keyStartLocation;
            NSRange keyRange = NSMakeRange(keyStartLocation, keyLength);
            NSString *key = [result substringWithRange:keyRange];
            NSRange replaceStringRange = NSMakeRange(keyRange.location - startTokenFlag.length,
                                                     keyRange.length + startTokenFlag.length + endTokenFlag.length);
            NSString *replaceString = [result substringWithRange:replaceStringRange];
            NSString *replacement = [[RMRomoMemory sharedInstance] knowledgeForKey:key];
            if (replacement) {
                result = [NSMutableString stringWithString:[result stringByReplacingOccurrencesOfString:replaceString
                                                                                            withString:replacement]];
            } else {
                return result;
            }
        }
    }
    
    return result;
}

//------------------------------------------------------------------------------
- (void)addAndAnimateView:(UIView *)view afterRomoSaysMessage:(NSString *)message;
{
    NSUInteger numberOfLines = [self numberOfLinesInString:message];
    
    view.top = self.view.height;
    [self.view addSubview:view];
    [UIView animateWithDuration:0.25 delay:0.2 * numberOfLines options:0
                     animations:^{
                         view.bottom = self.view.height;
                     } completion:nil];
}

//------------------------------------------------------------------------------
- (void)removeAndAnimateView:(UIView *)view afterRomoSaysMessage:(NSString *)message completion:(void (^)(BOOL))completion
{
    NSUInteger numberOfLines = [self numberOfLinesInString:message];
    
    if (view.superview) {
        [UIView animateWithDuration:0.2 delay:0.2 * numberOfLines options:0
                         animations:^{
                             view.top = self.view.height;
                         } completion:^(BOOL finished) {
                             [view removeFromSuperview];
                             if (completion) {
                                 completion(finished);
                             }
                         }];
    }
}

//------------------------------------------------------------------------------
- (NSUInteger)numberOfLinesInString:(NSString *)string
{
    NSUInteger numberOfLines, index, stringLength = [string length];
    
    for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++) {
        index = NSMaxRange([string lineRangeForRange:NSMakeRange(index, 0)]);
    }
    
    return numberOfLines;
}

//------------------------------------------------------------------------------
- (RMTouchLocation)touchLocationforString:(NSString*)locationString
{
    if ([locationString isEqualToString:@"nose"]) {
        return RMTouchLocationNose;
    } else if ([locationString isEqualToString:@"forehead"]) {
        return RMTouchLocationChin;
    } else if ([locationString isEqualToString:@"chin"]) {
        return RMTouchLocationChin;
    } else if ([locationString isEqualToString:@"left eye"]) {
        return RMTouchLocationLeftEye;
    } else if ([locationString isEqualToString:@"right eye"]) {
        return RMTouchLocationRightEye;
    }
    
    return RMTouchLocationNone;
}

//------------------------------------------------------------------------------
- (void)executeActionBlock
{
#ifdef INTERACTION_SCRIPT_DEBUG
    NSMutableString *executionString = [NSMutableString stringWithFormat:@"\tExecuting Block %d", self.blockNumber];
    NSString *desc = self.blocks[self.blockNumber][@"description"];
    if (desc) {
        [executionString appendFormat:@" (%@)", desc];
    }
    DDLogVerbose(@"%@", executionString);
#endif
    self.state = RMInteractionScriptState_ExecutingActions;
    [self _executeAction:self.actions[self.actionNumber]];
}

//------------------------------------------------------------------------------
- (void)sayText:(NSString *)textString withAutoDismiss:(BOOL)autoDismiss
{
    // If we have an exit condition and we're on our last action
    // for the block, then don't autodismiss the text
    autoDismiss = ( autoDismiss && !(self.hasExitCondition &&
                                     (self.actionNumber == (self.numberOfActionsInBlock - 1))) );
    
    
    self.talking = YES;
    
    [self.Romo.voice say:textString
               withStyle:RMVoiceStyleSLS
             autoDismiss:autoDismiss];
}

#pragma mark - Touch Handlers
//------------------------------------------------------------------------------
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    if (self.talking) {
        if (self.hasExitCondition) {
            // If the text is not the last action block, dismiss it
            // If it is the last prompt, then keep it because
            // it's probably telling the user to do something other thann tap
            if (self.actionNumber < (self.numberOfActionsInBlock - 1)) {
                [self.Romo.voice dismiss];
            }
        } else {
            [self.Romo.voice dismiss];
        }
    }
}

//------------------------------------------------------------------------------
- (void)touch:(RMTouch *)touch detectedTickleAtLocation:(RMTouchLocation)location
{
    if (self.waitingForTouch) {
        if (self.touchEventCondition == location || self.touchEventCondition == RMTouchLocationNone) {
            self.waitingForTouch = NO;
            self.conditionMet = YES;
        }
    }
}

//------------------------------------------------------------------------------
- (void)touch:(RMTouch *)touch endedPokingAtLocation:(RMTouchLocation)location
{
    if (self.waitingForPokes) {
        if (self.touchEventCondition == location || self.touchEventCondition == RMTouchLocationNone) {
            self.waitingForPokes = NO;
            self.conditionMet = YES;
        }
    }
}

#pragma mark - Delegates!
//------------------------------------------------------------------------------
- (void)didDetectFace:(RMFace *)face
{
    if (self.waitingForFace) {
        self.waitingForFace = NO;
        self.conditionMet = YES;
    }
}
- (void)didLoseFace
{
    if (self.waitingForFaceDisappear) {
        self.waitingForFaceDisappear = NO;
        self.conditionMet = YES;
    }
    
}

//------------------------------------------------------------------------------
- (void)characterDidFinishExpressing:(RMCharacter *)character
{
    if (self.state == RMInteractionScriptState_WaitingForExpressionBeforeStarting) {
        [self start];
    } else if (self.talkingAndExpressing) {
        self.expressingFinished = YES;
        
        if (self.talkingFinished) {
            self.talkingAndExpressing = NO;
            [self finishedAction];
        }
    } else {
        [self finishedAction];
    }
}

//------------------------------------------------------------------------------
- (void)speechDismissedForVoice:(RMVoice *)voice
{
    if (self.scriptIsFinished ||
        (!self.talking && !self.talkingAndExpressing && !self.askingQuestion)) {
        return;
    }
    
    if (self.talking) {
        self.talking = NO;
    }
    
    self.askingQuestion = NO;
    
    if (self.talkingAndExpressing) {
        self.talkingFinished = YES;
        
        if (self.expressingFinished) {
            self.talkingAndExpressing = NO;
            [self finishedAction];
        }
    } else {
        [self finishedAction];
    }
}

//------------------------------------------------------------------------------
- (void)userDidSelectOptionAtIndex:(int)optionIndex
                          forVoice:(RMVoice *)voice
{
    [voice dismiss];
    if (self.lastQuestionKey) {
        [[RMRomoMemory sharedInstance] setKnowledge:self.lastChoices[optionIndex]
                                             forKey:self.lastQuestionKey];
    }
}

//------------------------------------------------------------------------------
- (void)blockingBehaviorDidFinish
{
    if (self.executingBlockingBehavior) {
        self.executingBlockingBehavior = NO;
        [self finishedAction];
    }
}

//------------------------------------------------------------------------------
- (void)robotDidDetectPickup
{
    if (self.waitingForPickedUp) {
        self.waitingForPickedUp = NO;
        self.conditionMet = YES;
#ifdef INTERACTION_SCRIPT_DEBUG
        DDLogVerbose(@"Detected Pickup");
#endif
    }
}

//------------------------------------------------------------------------------
- (void)robotDidDetectPutDown
{
    if (self.waitingForPutDown) {
        self.waitingForPutDown = NO;
        self.conditionMet = YES;
#ifdef INTERACTION_SCRIPT_DEBUG
        DDLogVerbose(@"Detected Putown");
#endif
    }
}

//------------------------------------------------------------------------------
- (void)robotDidDetectShake
{
    if (self.waitingForShake) {
        self.waitingForShake = NO;
        self.conditionMet = YES;
    }
}

//------------------------------------------------------------------------------
- (void)loudSoundDetectorDetectedLoudSound:(RMLoudSoundDetector *)loudSoundDetector
{
    if (self.waitingForLoudSound) {
        self.waitingForLoudSound = NO;
        self.conditionMet = YES;
    }
}

//------------------------------------------------------------------------------
- (void)loudSoundDetectorDetectedEndOfLoudSound:(RMLoudSoundDetector *)loudSoundDetector
{
    if (self.waitingForClap) {
        self.waitingForClap = NO;
        self.conditionMet = YES;
    }
}

#pragma mark - UITextFieldDelegate methods
//------------------------------------------------------------------------------
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (![textField isEqual:self.textInputField]) {
        return YES;
    }
    
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.view.top = -kPortaitKeyboardHeight;
                     }];
    
    [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, 1.0, 0.5)
                            animated:YES];
    
    return YES;
}

//------------------------------------------------------------------------------
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    if (![textField isEqual:self.textInputField]) {
        return YES;
    }
    
    [UIView animateWithDuration:0.25 animations:^{
        self.view.top = 0;
    }];
    
    [self.Romo.character lookAtDefault];
    
    return YES;
}

//------------------------------------------------------------------------------
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (![textField isEqual:self.textInputField] || ![textField hasValidInput]) {
        return YES;
    }
    
    if (self.lastQuestionKey) {
        [[RMRomoMemory sharedInstance] setKnowledge:textField.text
                                             forKey:self.lastQuestionKey];
    }
    
    [textField resignFirstResponder];
    [self.Romo.voice dismiss];
    [self removeAndAnimateView:textField
          afterRomoSaysMessage:self.lastQuestion
                    completion:^(BOOL finished) {
                        textField.text = nil;
                    }];
    
    return YES;
}

#pragma mark -- Keyboard notifications --
//------------------------------------------------------------------------------
- (void) keyboardDidShow:(NSNotification*)notification
{
    CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.view.top = -keyboardFrame.size.height;
}

- (RMCutscene *)cutscene
{
    if (!_cutscene) {
        _cutscene = [[RMCutscene alloc] init];
    }
    return _cutscene;
}


@end
