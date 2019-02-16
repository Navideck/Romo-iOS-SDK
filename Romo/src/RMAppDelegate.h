//
//  RMAppDelegate.h
//  Romo
//

#import <Romo/RMCore.h>

@class RMRobotController;

@interface RMAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;

/**
 Only one controller can be active, granted full and exclusive access to
 the robot, the character, and the view
 */
@property (nonatomic, strong) RMRobotController *robotController;

/**
 When a controller wants to resign, it should replace itself with the default
 controller
 */
@property (nonatomic, readonly, strong) RMRobotController *defaultController;

/**
 Changes the robotController property through an animated transition while keeping the previous controller alive in the stack
 Calling -popRobotController reveals the previous
 */
- (void)pushRobotController:(RMRobotController *)robotController;
- (void)popRobotController;

@end
