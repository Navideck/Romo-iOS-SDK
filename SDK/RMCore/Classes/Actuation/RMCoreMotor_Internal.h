//
//  RMCoreMotor_Internal.h
//  RMCore
//

@class RMCoreRobot;

@interface RMCoreMotor (Internal)

/**
 The robot the motor is part of.
 */
@property (nonatomic, readonly, weak) RMCoreRobot *robot;

@property (nonatomic) float powerLevel;

- (RMCoreMotor *)initWithAxis:(RMCoreMotorAxis)motorAxis
                    pwmScalar:(unsigned int)pwmScalar
        motorCurrentAvailable:(BOOL)motorCurrentAvailable
                        robot:(RMCoreRobot *)robot;

@end
