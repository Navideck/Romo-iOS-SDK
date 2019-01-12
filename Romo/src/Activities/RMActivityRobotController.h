//
//  RMActivityRobotController.h
//  Romo
//

#import "RMRobotController.h"
#import "RMProgressManager.h"

@protocol RMActivityRobotControllerDelegate;

@interface RMActivityRobotController : RMRobotController

@property (nonatomic, weak) id<RMActivityRobotControllerDelegate> delegate;

/**
 The chapter this activity represents
 Subclasses must override the getter
 */
@property (nonatomic, readonly) RMChapter chapter;

/**
 Human-friendly capitalized title
 e.g. "Favorite Color"
 Subclasses must override the getter
 */
@property (nonatomic, copy) NSString *title;

/**
 Direct user-interaction events grab Romo's undivided attention, like pokes and pick-ups
 When attentive, the robot should stop driving and playing, and relevant UI elements are shown
 */
@property (nonatomic, getter=isAttentive) BOOL attentive;

/**
 Whether this controller shows a "?" help button
 Defaults to YES
 */
@property (nonatomic, readonly) BOOL showsHelpButton;

@property (nonatomic, readonly) BOOL showsSpaceButton;

/**
 Returns the progress of the activity on the interval [0.0, 1.0]
 */
+ (double)activityProgress;

/** 
 Called when the user explicitly asks for help
 Subclasses must override the implementation of this method
 */
- (void)userAskedForHelp;

/**
 Resets a timer for Romo's attention span
 */
- (void)renewAttention;

@end

@protocol RMActivityRobotControllerDelegate <NSObject>

/**
 When the user is done with this activity
 */
- (void)activityDidFinish:(RMActivityRobotController *)activity;

@end
