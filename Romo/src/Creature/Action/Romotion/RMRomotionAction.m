//
//  RMRomotionAction.m
//  Romo
//

#import "RMRomotionAction.h"
#import "RMRomo.h"

@implementation RMRomotionAction

+ (id)actionWithLeftMotorPower:(float)leftMotorPower
               rightMotorPower:(float)rightMotorPower
                tiltMotorPower:(float)tiltMotorPower
                   forDuration:(float)duration
                         robot:(RMCoreRobot<DifferentialDriveProtocol,HeadTiltProtocol> *)robot
{
    RMRomotionAction *action = [[RMRomotionAction alloc] init];
    action.leftMotorPower = leftMotorPower;
    action.rightMotorPower = rightMotorPower;
    action.tiltMotorPower = tiltMotorPower;
    action.duration = duration;
    action.robot = robot;
    return action;
}

- (void)execute
{
    [self.robot driveWithLeftMotorPower:self.leftMotorPower rightMotorPower:self.rightMotorPower];
    [self.robot tiltWithMotorPower:self.tiltMotorPower];
}

@end
