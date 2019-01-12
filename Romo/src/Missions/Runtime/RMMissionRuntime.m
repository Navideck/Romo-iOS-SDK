//
//  RMMissionRuntime.m
//  Romo
//

#import "RMMissionRuntime.h"
#import "RMRomo.h"
#import "RMMission.h"
#import "RMEvent.h"
#import "RMParameter.h"
#import "RMAction.h"
#import "RMActionRuntime.h"
#import "RMSoundEffect.h"
#import "RMRomotionAction.h"
#import "RMLookAction.h"

static NSString *const romotionTangoSoundEffect = @"Activity-Tango-%d";
static const float romotionTangoStepDuration = 2.75;
static const int kNumStepsInTango = 8;

@interface RMMissionRuntime () <RMActionRuntimeDelegate>

@property (nonatomic, strong) RMActionRuntime *API;
@property (nonatomic, strong) NSArray *script;
@property (nonatomic) int currentActionIndex;
@property (nonatomic, copy) void (^completion)(BOOL finished);

@end

@implementation RMMissionRuntime

static BOOL stopping;
static RMMissionRuntime *instance;

+ (RMMissionRuntime *)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RMMissionRuntime alloc] init];
        stopping = NO;
    });
    return instance;
}

+ (void)runUserTrainedAction:(RMUserTrainedAction)action onRomo:(RMRomo *)Romo completion:(void (^)(BOOL))completion
{
    [self stopRunning];
    stopping = NO;

    if (action == RMUserTrainedActionRomotionTangoWithMusic) {
        Romo.character.emotion = RMCharacterEmotionHappy;
        
        // Wait 2 seconds and kick it off!
        double delayInSeconds = 2.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [Romo.robot tiltToAngle:90 completion:^(BOOL success) {
                [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
                [self runRomotionTangoWithRomo:Romo step:0 completion:^(BOOL didFinish) {
                    if (completion) {
                        completion(didFinish);
                    }
                    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                }];

            }];
        });
    } else {
        NSArray *script = [self scriptForAction:action];
        
        if (script) {
            [self sharedInstance].API.Romo = Romo;
            script = [RMMission flattenedScript:script];
            [RMMissionRuntime sharedInstance].completion = completion;
            [[RMMissionRuntime sharedInstance] runScript:script];
        } else if (completion) {
            completion(NO);
        }
    }
}

+ (void)stopRunning
{
    stopping = YES;
    [instance stopRunning];
}

#pragma mark - Private Properties

+ (NSArray *)scriptForAction:(RMUserTrainedAction)action
{
    int chapter = -1;
    int index = -1;
    RMEvent *eventToMatch = nil;
    BOOL userDefined = NO;
    NSString *userDefinedName = nil;
    
    switch (action) {
        case RMUserTrainedActionRomotionTango:
            chapter = 1;
            index = 12;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventMissionStart];
            break;
            
        case RMUserTrainedActionDriveInACircle:
            chapter = 1;
            index = 6;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventMissionStart];
            break;
            
        case RMUserTrainedActionDriveInASquare:
            chapter = 1;
            index = 8;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventMissionStart];
            break;
            
        case RMUserTrainedActionNo:
            chapter = 1;
            index = 9;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventMissionStart];
            userDefined = YES;
            userDefinedName = @"No!";
            break;
            
        case RMUserTrainedActionPoke:
            chapter = 2;
            index = 1;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventPokeAnywhere];
            break;
            
        case RMUserTrainedActionTickleChin:
            chapter = 2;
            index = 2;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventTickle];
            eventToMatch.parameter.value = @"chin";
            break;
            
        case RMUserTrainedActionTickleNose:
            chapter = 2;
            index = 2;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventTickle];
            eventToMatch.parameter.value = @"nose";
            break;
            
        case RMUserTrainedActionTickleForehead:
            chapter = 2;
            index = 2;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventTickle];
            eventToMatch.parameter.value = @"forehead";
            break;
            
        case RMUserTrainedActionPickedUp:
            chapter = 2;
            index = 6;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventPickedUp];
            break;
            
        case RMUserTrainedActionPutDown:
            chapter = 2;
            index = 6;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventPutDown];
            break;
            
        case RMUserTrainedActionLoudSound:
            chapter = 3;
            index = 1;
            eventToMatch = [[RMEvent alloc] initWithType:RMEventHearsLoudSound];
            break;
            
        case RMUserTrainedActionInvalid:
        default:
            break;
    }
    
    if (chapter > 0 && index > 0) {
        if (!userDefined) {
            NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *fileName = [documentsDirectory stringByAppendingPathComponent:[[NSString stringWithFormat:savedSolutionKey, chapter, index] stringByAppendingString:@".plist"]];
            
            NSArray *events = [NSArray arrayWithContentsOfFile:fileName];
            
            for (NSDictionary *eventDictionary in events) {
                NSString *eventName = eventDictionary[@"event"];
                RMEvent *event = [[RMEvent alloc] initWithName:eventName];
                event.parameter.value = eventDictionary[@"eventParameter"];
                
                if (event.type == eventToMatch.type && (!eventToMatch.parameter || [event.parameter.value isEqual:eventToMatch.parameter.value])) {
                    NSArray *serializedActions = eventDictionary[@"script"];
                    NSMutableArray *script = [NSMutableArray arrayWithCapacity:serializedActions.count];
                    for (NSDictionary *serializedAction in serializedActions) {
                        RMAction *action = [[RMAction alloc] initWithDictionary:serializedAction];
                        [script addObject:action];
                    }
                    return script;
                }
            }
        } else {
            NSString *fileName = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"User-Action-%@", userDefinedName] ofType:@"plist"];
            NSArray *serializedActions = [NSArray arrayWithContentsOfFile:fileName];
            
            NSMutableArray *script = [NSMutableArray arrayWithCapacity:serializedActions.count];
            for (NSDictionary *serializedAction in serializedActions) {
                RMAction *action = [[RMAction alloc] initWithDictionary:serializedAction];
                [script addObject:action];
            }
            return script;
        }
    }
    
    return nil;
}

#pragma mark - Romotion Tango

+ (void)runRomotionTangoWithRomo:(RMRomo *)Romo step:(int)step completion:(void (^)(BOOL didFinish))completion
{
    if (stopping) {
        stopping = NO;
        return;
    }
    
    if (step < kNumStepsInTango) {
        [RMSoundEffect playForegroundEffectWithName:[NSString stringWithFormat:romotionTangoSoundEffect, step] repeats:NO gain:1.0];
        
        NSArray *dance = nil;
        NSArray *looks = nil;
        
        BOOL shouldChangeEmotion = NO;
        RMCharacterEmotion emotion = RMCharacterEmotionHappy;
        float emotionTransitionTime = 0.0;
        float moveDuration;
        
        switch (step) {
            case 0: {
                moveDuration = 1.75;
//                waitDuration = 1.0;

                shouldChangeEmotion = YES;
                emotionTransitionTime = moveDuration - 0.3;
                emotion = RMCharacterEmotionScared;
                
                dance = @[
                          [RMRomotionAction actionWithLeftMotorPower:0.75 rightMotorPower:-0.65 tiltMotorPower:-1.0 forDuration:0.3 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:-0.65 rightMotorPower:0.75 tiltMotorPower:1.0 forDuration:0.3 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:0.6 tiltMotorPower:-1.0 forDuration:0.2 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:-0.65 rightMotorPower:-0.65 tiltMotorPower:0.0 forDuration:0.15 robot:Romo.robot],

                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:1.0 robot:Romo.robot]
                          ];
                
                looks = @[
                          [RMLookAction actionWithLocation:RMPoint3DMake(-1.0, -0.9, 0.5) forDuration:0.3 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(-1.0, 0.8, 0.5) forDuration:0.2 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(1.0, -0.8, 0.5) forDuration:0.3 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(1.0, 0.9, 0.5) forDuration:0.2 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.5, 0.2, 0.5) forDuration:0.2 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.1, 0.3, 0.5) forDuration:0.2 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.0, 0.0, 0.85) forDuration:0.3 withRomo:Romo]
                          ];
                break;
            }
            case 1: {
                moveDuration = 1.75;
//                waitDuration = 1.0;

                shouldChangeEmotion = YES;
                emotionTransitionTime = moveDuration - 0.2;
                emotion = RMCharacterEmotionIndifferent;
                
                dance = @[
                          [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:-0.55 tiltMotorPower:0.5 forDuration:0.3 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:0.6 tiltMotorPower:-1.0 forDuration:0.3 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:1.0 forDuration:0.25 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:-0.8 rightMotorPower:0.8 tiltMotorPower:-0.4 forDuration:0.3 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.9 forDuration:0.35 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.8 forDuration:0.35 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot]
                          ];
                
                looks = @[
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.7, -0.9, 0.5) forDuration:0.5 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.6, 0.8, 0.5) forDuration:0.9 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.0, 0.0, 1.0) forDuration:0.3 withRomo:Romo]
                          ];
                break;
            }
            case 2: {
                moveDuration = 1.75;
//                waitDuration = 1.0;

                shouldChangeEmotion = YES;
                emotionTransitionTime = moveDuration - 0.2;
                emotion = RMCharacterEmotionCurious;
                
                dance = @[
                          [RMRomotionAction actionWithLeftMotorPower:0.75 rightMotorPower:-0.35 tiltMotorPower:1.0 forDuration:0.3 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:-0.35 rightMotorPower:0.75 tiltMotorPower:-0.3 forDuration:0.3 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:0.6 tiltMotorPower:0.7 forDuration:0.2 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:-0.65 rightMotorPower:-0.65 tiltMotorPower:0.0 forDuration:0.15 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:1.0 robot:Romo.robot]
                          ];
                
                looks = @[
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.6, -0.7, 0.5) forDuration:0.3 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.1, -0.5, 0.5) forDuration:0.2 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.3, -0.8, 0.5) forDuration:0.3 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.7, -0.4, 0.5) forDuration:0.6 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.0, 0.0, 0.85) forDuration:0.3 withRomo:Romo]
                          ];
                break;
            }
            case 3: {
                moveDuration = 1.9;
//                waitDuration = 0.85;

                shouldChangeEmotion = YES;
                emotionTransitionTime = moveDuration - .475;
                emotion = RMCharacterEmotionBewildered;
                
                dance = @[
                          [RMRomotionAction actionWithLeftMotorPower:-0.75 rightMotorPower:0.65 tiltMotorPower:-1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.65 rightMotorPower:-0.75 tiltMotorPower:1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:-0.75 rightMotorPower:0.65 tiltMotorPower:-1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:-0.35 rightMotorPower:-0.75 tiltMotorPower:1.0 forDuration:0.2 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.7 tiltMotorPower:-1.0 forDuration:0.2 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:-0.65 rightMotorPower:-0.65 tiltMotorPower:0.0 forDuration:0.15 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:1.0 robot:Romo.robot]
                          ];
                
                looks = @[
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.0, 1.0, 0.5) forDuration:0.15 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.4, 0.8, 0.5) forDuration:0.15 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.7, 0.5, 0.5) forDuration:0.45 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.3, 0.2, 0.5) forDuration:0.2 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.3, 0.0, 0.5) forDuration:0.2 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.4, 0.4, 0.5) forDuration:0.2 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.0, 0.0, 0.5) forDuration:0.5 withRomo:Romo]
                          ];
                break;
            }
            case 4: {
                moveDuration = 1.05;
//                waitDuration = 1.7;

                shouldChangeEmotion = YES;
                emotionTransitionTime = moveDuration + 0.35;
                emotion = RMCharacterEmotionCurious;

                dance = @[
                          [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.15 tiltMotorPower:1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:-0.15 rightMotorPower:-0.45 tiltMotorPower:-1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:-0.45 rightMotorPower:-0.15 tiltMotorPower:1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.15 rightMotorPower:0.45 tiltMotorPower:-1.0 forDuration:0.15 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:0.5 tiltMotorPower:1.0 forDuration:0.15 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.6 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:1.0 forDuration:0.4 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.1 robot:Romo.robot]
                          ];
                
                looks = @[
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.7, -0.1, 0.5) forDuration:0.6 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.6, 0.4, 0.5) forDuration:1.0 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.0, 0.0, 0.5) forDuration:0.3 withRomo:Romo]
                          ];
                break;
            }
            case 5: {
                moveDuration = 1.05;
//                waitDuration = 1.7;

                shouldChangeEmotion = YES;
                emotionTransitionTime = moveDuration + 0.45;
                emotion = RMCharacterEmotionExcited;
                
                dance = @[
                          [RMRomotionAction actionWithLeftMotorPower:-0.45 rightMotorPower:-0.15 tiltMotorPower:-1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.15 rightMotorPower:0.45 tiltMotorPower:1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.15 tiltMotorPower:-1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:-0.15 rightMotorPower:-0.45 tiltMotorPower:1.0 forDuration:0.15 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:-1.0 forDuration:0.15 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.6 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-1.0 forDuration:0.4 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.1 robot:Romo.robot]
                          ];
                
                looks = @[
                          [RMLookAction actionWithLocation:RMPoint3DMake(1.0, 0.1, 0.5) forDuration:0.6 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.9, -0.1, 0.5) forDuration:1.0 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.0, 0.0, 0.5) forDuration:0.3 withRomo:Romo]
                          ];
                break;
            }
            case 6: {
                moveDuration = 1.05;
//                waitDuration = 1.7;

                shouldChangeEmotion = YES;
                emotionTransitionTime = moveDuration + 0.5;
                emotion = RMCharacterEmotionHappy;
                
                dance = @[
                          [RMRomotionAction actionWithLeftMotorPower:-0.65 rightMotorPower:0.65 tiltMotorPower:0.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.75 rightMotorPower:-0.75 tiltMotorPower:0.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:-0.85 rightMotorPower:0.85 tiltMotorPower:0.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.95 rightMotorPower:-0.95 tiltMotorPower:0.0 forDuration:0.15 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:0.5 tiltMotorPower:1.0 forDuration:0.15 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.3 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.3 forDuration:0.3 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.5 forDuration:0.3 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.7 forDuration:0.45 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:Romo.robot]
                          ];
                
                looks = @[
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.1, 0.9, 0.5) forDuration:0.6 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.05, -1.0, 0.5) forDuration:0.8 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.0, 0.0, 0.5) forDuration:0.15 withRomo:Romo]
                          ];
                break;
            }
            case 7: {
//                moveDuration = 1.85;
//                waitDuration = 0.9;
                
                dance = @[
                          [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.15 tiltMotorPower:-0.6 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:-0.15 rightMotorPower:-0.45 tiltMotorPower:-1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:-0.45 rightMotorPower:-0.15 tiltMotorPower:0.4 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.15 rightMotorPower:0.45 tiltMotorPower:-0.5 forDuration:0.15 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:0.7 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:-0.15 rightMotorPower:-0.45 tiltMotorPower:-1.0 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:-0.45 rightMotorPower:-0.25 tiltMotorPower:0.7 forDuration:0.15 robot:Romo.robot],
                          [RMRomotionAction actionWithLeftMotorPower:0.65 rightMotorPower:0.65 tiltMotorPower:-0.9 forDuration:0.15 robot:Romo.robot],
                          
                          [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:1.0 robot:Romo.robot]
                          ];
                
                looks = @[
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.0, 1.0, 0.5) forDuration:0.15 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.3, 0.6, 0.5) forDuration:0.15 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.4, 0.5, 0.5) forDuration:0.15 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.1, 0.2, 0.5) forDuration:0.15 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.3, 0.0, 0.5) forDuration:0.35 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(-0.2, 0.4, 0.5) forDuration:0.15 withRomo:Romo],
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.3, 0.0, 0.5) forDuration:0.15 withRomo:Romo],
                          
                          [RMLookAction actionWithLocation:RMPoint3DMake(0.0, 0.0, 0.5) forDuration:0.5 withRomo:Romo]
                          ];
                break;
            }
            default:
                break;
        }
        [self executeStep:0 forRomotionActions:dance];
        [self executeStep:0 forLookActions:looks];
        
        if (shouldChangeEmotion) {
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(emotionTransitionTime * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                if (!stopping) {
                    Romo.character.emotion = emotion;
                }
            });
        }
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(romotionTangoStepDuration * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            if (!stopping) {
                [self runRomotionTangoWithRomo:Romo step:step+1 completion:completion];
            }
        });
    } else if (completion) {
        completion(YES);
    }
}

+ (void)executeStep:(int)step forRomotionActions:(NSArray *)actions
{
    RMRomotionAction* action = (RMRomotionAction *)actions[step];
    [action execute];
    
    if (step + 1 < actions.count) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(action.duration * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self executeStep:step+1 forRomotionActions:actions];
        });
    }
}

+ (void)executeStep:(int)step forLookActions:(NSArray *)actions
{
    RMLookAction* action = (RMLookAction *)actions[step];
    [action execute];
    
    if (step + 1 < actions.count) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(action.duration * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self executeStep:step+1 forLookActions:actions];
        });
    }
}

#pragma mark - Private Class Methods

- (void)runScript:(NSArray *)script
{
    self.script = script;
    self.currentActionIndex = 0;
    [self runNextMethod];
}

- (void)runNextMethod
{
    if (self.API.readyToRun) {
        if (self.script.count > self.currentActionIndex) {
            RMAction *action = self.script[self.currentActionIndex];
            self.currentActionIndex++;
            
            [self.API runAction:action];
        } else {
            if (self.completion) {
                self.completion(YES);
            }
        }
    }
}

- (void)actionRuntimeBecameReadyToRunNextAction:(RMActionRuntime *)actionRuntime
{
    [self runNextMethod];
}

- (void)actionRuntime:(RMActionRuntime *)actionRuntime finishedRunningAction:(RMAction *)action
{
    
}

- (void)stopRunning
{
    self.script = nil;
    if (_API) {
        [self.API.Romo.robot stopAllMotion];
        self.API.delegate = nil;
        self.API.Romo = nil;
        self.API = nil;
    }
}

- (RMActionRuntime *)API
{
    if (!_API) {
        _API = [[RMActionRuntime alloc] init];
        _API.delegate = self;
    }
    return _API;
}

@end
