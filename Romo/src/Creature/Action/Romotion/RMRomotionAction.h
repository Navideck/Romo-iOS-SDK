//
//  RMRomotionAction.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <Romo/RMCore.h>

@interface RMRomotionAction : NSObject

@property (nonatomic) float leftMotorPower;
@property (nonatomic) float rightMotorPower;
@property (nonatomic) float tiltMotorPower;
@property (nonatomic) float duration;
@property (nonatomic, weak) RMCoreRobot<DifferentialDriveProtocol, HeadTiltProtocol> *robot;

+ (id)actionWithLeftMotorPower:(float)leftMotorPower
               rightMotorPower:(float)rightMotorPower
                tiltMotorPower:(float)tiltMotorPower
                   forDuration:(float)duration
                         robot:(RMCoreRobot<DifferentialDriveProtocol, HeadTiltProtocol> *)robot;
- (void)execute;

@end
