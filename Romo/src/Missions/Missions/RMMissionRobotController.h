 //
//  RMMissionRobotController.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMRobotController.h"

@class RMProgressManager;
@class RMMission;
@class RMSpaceScene;

@interface RMMissionRobotController : RMRobotController

/**
 Starts by displaying this mission's briefing
 */
- (id)initWithMission:(RMMission *)mission;

@end
