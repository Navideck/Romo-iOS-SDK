//
//  RMRobotController.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMRomo.h"

@interface RMRobotController : UIViewController <RMRomoDelegate, RMTouchDelegate, RMEquilibrioceptionDelegate, RMCharacterDelegate, RMVisionDelegate, RMLoudSoundDetectorDelegate>

/** Only available when active */
@property (nonatomic, strong) RMRomo *Romo;

/**
 Is this robot controller the exclusively active one?
 This includes exclusive access to the robot and character, as well as broadcasting state, etc.
 */
@property (nonatomic, readonly, getter=isActive) BOOL active;

/**
 When a robot controller will become active, it's RMRomo will be configured to activate only these functionalities
 If a robot controller wants to change the functionalities at any later point (while active), set RMRomo's -activeFunctionalities property
 */
@property (nonatomic) RMRomoFunctionalities initiallyActiveFunctionalities;

/**
 When a robot controller will become active, it's RMRomo will be configured to allow for these interruptions by default
 If a robot controller wants to change these at any later point (while active), set RMRomo's -allowedInterruptions property
 */
@property (nonatomic) RMRomoInterruptions initiallyAllowedInterruptions;

/**
 A set of RMVisionModule strings that are enabled when this robot controller becomes active
 */
@property (nonatomic, strong) NSSet *initiallyActiveVisionModules;

/** Once animations start, appears on-screen before -controllerDidBecomeActive */
- (void)controllerWillBecomeActive;

/** First access to Romo, after animation completes */
- (void)controllerDidBecomeActive;

/** Last access to Romo, starts animation to off-screen */
- (void)controllerWillResignActive;

/** No access to Romo, called after removed from screen */
- (void)controllerDidResignActive;

- (void)robotDidConnect:(RMCoreRobot *)robot;
- (void)robotDidDisconnect:(RMCoreRobot *)robot;

/**
 NSNotifications posted from robot controller when active state changes.
 */
extern NSString *const RMRobotControllerDidBecomeActiveNotification;
extern NSString *const RMRobotControllerDidResignActiveNotification; 

@end
