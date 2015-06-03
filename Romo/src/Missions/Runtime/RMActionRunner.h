//
//  RMActionRunner.h
//  Romo
//

#import <Foundation/Foundation.h>

@class RMAction;
@class RMRomo;
@class RMVision;
@class RMExploreBehavior;

@protocol RMActionRunnerDelegate;

@interface RMActionRunner : NSObject

@property (nonatomic, weak) id<RMActionRunnerDelegate> delegate;

@property (nonatomic, strong) RMRomo *Romo;

@property (nonatomic, strong) RMVision *vision;

/** The parameters of this action can be influenced by real-world runtime data */
@property (nonatomic, strong) RMAction *runningAction;

@property (nonatomic, strong, readonly) RMExploreBehavior *exploreBehavior;

/** A list of all actions */
+ (NSArray *)actions;

/** 
 Stops any actions currently being run but isn't required to release any locks
 Also, actions can safely stop themselves again without any problems (e.g. scheduled stops after a few seconds can still fire)
 */
- (void)stopExecution;

@end

@protocol RMActionRunnerDelegate <NSObject>

- (void)runnerBecameReadyToContinueExecution:(RMActionRunner *)runner;

@end
