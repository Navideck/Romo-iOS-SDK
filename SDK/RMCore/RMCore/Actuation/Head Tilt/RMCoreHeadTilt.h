//
//  RMCoreHeadTilt.h
//  RMCore
//

#import <Foundation/Foundation.h>
#import "HeadTiltProtocol.h"
#import "RMCoreRobot.h"
#import "RobotMotionProtocol.h"

@interface RMCoreHeadTilt : NSObject

@property (nonatomic, weak) RMCoreRobot<HeadTiltProtocol, RobotMotionProtocol> *robot;
@property (nonatomic, readonly) double headAngle;
@property (nonatomic, readonly, getter=isTilting) BOOL tilting;

- (void)tiltWithMotorPower:(float)motorPower;
- (void)tiltByAngle:(float)angle completion:(void (^)(BOOL finished))completion;
- (void)tiltToAngle:(float)angle completion:(void (^)(BOOL finished))completion;
- (void)stopTilting;

@end
