//
//  RMWiFiDriveManager.h
//  Romo
//

#import <Foundation/Foundation.h>
#import "RMRobotController.h"
#import "RMSession.h"
#import "RMDpad.h"

@interface RMWiFiDriveRobotController : RMRobotController

@property (nonatomic, getter=isBroadcasting) BOOL broadcasting;
/**
 NSNotification for when the session starts
 */
extern NSString *const RMWiFiDriveRobotControllerSessionDidStart;
/**
 NSNotification for when the session ends
 */
extern NSString *const RMWiFiDriveRobotControllerSessionDidEnd;

@end
