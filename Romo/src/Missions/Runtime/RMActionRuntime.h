//
//  RMActionRuntime.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <Romo/RMCore.h>
#import <Romo/RMVision.h>

@class RMAction;
@class RMRomo;
@class RMStasisVirtualSensor;

@protocol RMActionRuntimeDelegate;

@interface RMActionRuntime : NSObject

@property (nonatomic, weak) id<RMActionRuntimeDelegate> delegate;
@property (nonatomic, strong) RMRomo *Romo;
@property (nonatomic, strong) RMVision *vision;
@property (nonatomic, strong) RMStasisVirtualSensor *stasisVirtualSensor;

@property (nonatomic, readonly) BOOL readyToRun;

/** Returns all actions */
+ (NSArray *)allActions;

/** Runs the action, sets -readyToRun to NO until -continueAsynchronousExecution is called  */
- (void)runAction:(RMAction *)action;

/** Immediately stops all concurrent actions which unlocks all keys */
- (void)stopAllActions;

@end

@protocol RMActionRuntimeDelegate <NSObject>

- (void)actionRuntimeBecameReadyToRunNextAction:(RMActionRuntime *)actionRuntime;
- (void)actionRuntime:(RMActionRuntime *)actionRuntime finishedRunningAction:(RMAction *)action;

@end
