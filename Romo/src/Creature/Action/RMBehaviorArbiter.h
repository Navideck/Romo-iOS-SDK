//
//  RMActivityAction.h
//  Romo
//

#import <Foundation/Foundation.h>
#import "RMObjectTrackingVirtualSensor.h"
#import "RMStasisVirtualSensor.h"

@class RMRomo;
@class RMVirtualSensor;

@protocol RMBehaviorArbiterDelegate;

typedef enum {
    RMActivityBehaviorNone = 0,
    RMActivityBehaviorMotionTriggeredColorTrainingLookForNegativeData,
    RMActivityBehaviorMotionTriggeredColorTrainingUpdated,
    RMActivityBehaviorMotionTriggeredColorTrainingFinished,
    RMActivityBehaviorObjectFollow,
    RMActivityBehaviorObjectCheckBehind,
    RMActivityBehaviorObjectHeldOverHead,
    RMActivityBehaviorObjectQuicklyFind,
    RMActivityBehaviorObjectSearch,
    RMActivityBehaviorObjectPossession,
    RMActivityBehaviorStasisRandomBounce,
    RMActivityBehaviorRequireDocking,
    RMActivityBehaviorSelfRighting,
    RMActivityBehaviorTooBright,
    RMActivityBehaviorTooDark,
    RMActivityBehaviorLineSearch,
} RMActivityBehavior;

@interface RMBehaviorArbiter : NSObject

@property (nonatomic, weak) id<RMBehaviorArbiterDelegate> delegate;

/** The Romo for character & robot */
@property (nonatomic, strong) RMRomo *Romo;

/**
 Which behaviors take precedence over others?
 Behaviors earlier in the array have higher priority
 e.g. [StasisRandomBounce, ObjectSearch, ObjectFollow]
 */
@property (nonatomic, strong) NSArray *prioritizedBehaviors;

/**
 A dictionary mapping behaviors to a maximum rate (sec) at which they can occur
 This is measured by the amount of time from when the behavior was last started
 e.g. Possession -> 12 sec
 e.g. Follow -> 0 sec (not rate limited)
 */
@property (nonatomic, strong) NSDictionary *behaviorRateLimits;

/** Virtual Sensors */
@property (nonatomic, readonly, strong) RMObjectTrackingVirtualSensor *objectTracker;
@property (nonatomic, readonly, strong) RMStasisVirtualSensor *stasisVirtualSensor;

@property (nonatomic, readonly, getter=isObjectTracking) BOOL objectTracking;

/**
 The prompt that Romo says when asking the user to wave something
 Defaults to "Wave a color for me to chase!"
 */
@property (nonatomic, strong) NSString *wavePrompt;

@property (nonatomic, getter=isLineFollowing) BOOL lineFollowing;

- (void)startLookingForNegativeDataWithCompletion:(void (^)(BOOL finished))completion;

- (void)startMotionTriggeredColorTrainingWithCompletion:(void (^)(BOOL finished))completion;
- (void)stopMotionTriggeredColorTraining;

- (void)startTrackingObject;
- (void)startTrackingObjectWithTrainingData:(RMVisionTrainingData *)trainingData;
- (void)stopTrackingObject;

- (void)startDetectingStasis;
- (void)stopDetectingStasis;

- (void)startBrightnessMetering;
- (void)stopBrightnessMetering;

@end

@protocol RMBehaviorArbiterDelegate <NSObject>

- (UIViewController *)viewController;
- (UIView *)view;

- (void)behaviorArbiter:(RMBehaviorArbiter *)behaviorArbiter didFinishExecutingBehavior:(RMActivityBehavior)behavior;

@optional
- (void)lineFollowIsFuckingUp;

@end