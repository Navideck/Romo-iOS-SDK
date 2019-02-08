//
//  RMCoreMotor.m
//  RMCore
//

#import "RMCoreMotor.h"
#import "RMCoreMotor_Internal.h"
#import "RMCoreRobot.h"
#import "RMCoreRobot_Internal.h"
#import "RMCoreRobotCommunication.h"
#import "RMCoreLeakyIntegrator.h"
#import <RMShared/RMMath.h>

@interface RMCoreMotor ()

@property (nonatomic, readwrite, weak) RMCoreRobot *robot;
@property (nonatomic, readwrite) RMCoreMotorAxis motorAxis;
@property (nonatomic, readwrite) unsigned int pwmScalar;
@property (nonatomic, readwrite) float powerLevel;
@property (nonatomic, readwrite) BOOL motorCurrentAvailable;
@property (nonatomic, readwrite) float motorCurrent;
@property (nonatomic, strong) RMCoreLeakyIntegrator *currentLeakyIntegrator;
@property (nonatomic, readwrite) int currentConsumptionThreshold;
@property (nonatomic, readwrite) BOOL isOverCurrent;

@end

@implementation RMCoreMotor


- (RMCoreMotor *)initWithAxis:(RMCoreMotorAxis)motorAxis
                    pwmScalar:(unsigned int)pwmScalar
        motorCurrentAvailable:(BOOL)motorCurrentAvailable
                        robot:(RMCoreRobot *)robot
{
    self = [super init];
    if (self) {        
        _motorAxis = motorAxis;
        _pwmScalar = pwmScalar;
        _motorCurrentAvailable = motorCurrentAvailable;
        _robot = robot;
    }
    return self;
}

- (void)setPowerLevel:(float)powerLevel
{
    // ensure that motor doesn't get power if it's been drawing too much current
    if(self.isOverCurrent)
    {
        powerLevel = 0;
    }
    
    powerLevel = CLAMP(-1.0, powerLevel, 1.0);
    _powerLevel = powerLevel;
    
    int pwmCommand = self.pwmScalar * _powerLevel;

    [self.robot.communication setMotorNumber:_motorAxis commandType:RMMotorCommandTypePWM value:pwmCommand];
}

- (float)motorCurrent
{
    if (_motorCurrentAvailable) {
        uint16_t requested = [self.robot.communication requestMotorCurrent:_motorAxis];
        return (float)requested;
    }
    return NAN;
}

- (void) startOverCurrentDetector
{
    const int kThresholdLenient = 15000;           // mA (this is ~1.5 minutes of
                                                   // continuous stall at full power)
    const int kThresholdStrict =  11000;           // mA (this gives ~40 seconds of
                                                   // cool down)

    const float kOverCurrentDetectFrequency = 1;   // Hz (pulled out of thin air)
    const float kLeakRate = 100;                   // mA/s (just a guess that worked)
    const float kMaxValue = 2 * kThresholdLenient; // mA (this is more than enough overhead)
    const float kMinValue = 0;                     // mA
    
    __weak RMCoreMotor *weakSelf = self;           // used to prevent cylcical referencing
    
    
    // create leaky integrator to track motor current consumption
    self.currentLeakyIntegrator = [[RMCoreLeakyIntegrator alloc]
                                   initWithFrequency:kOverCurrentDetectFrequency
                                   leakRate:kLeakRate
                                   maxValue:kMaxValue
                                   minValue:kMinValue
                                   inputSource:^double
                                   {
                                       // pass in instanteous current value
                                       if(weakSelf.motorCurrent != NAN)
                                       {
                                           return weakSelf.motorCurrent;
                                       }
                                       else
                                       {
                                           // this is an error condition, it should
                                           // not happen (if it does we'll do the
                                           // safe thing and not run)
                                           weakSelf.isOverCurrent = YES;
                                           return 0;
                                       }
                                   }
                                   outputSink:^(float integratedCurrent)
                                   {
                                       // test if current consumption is too high
                                       if(integratedCurrent > weakSelf.currentConsumptionThreshold)
                                       {
                                           // motor is too hot, shut it down and adjust
                                           // threshold to enforce cool-down period
                                           weakSelf.isOverCurrent = YES;
                                           [weakSelf setPowerLevel:0];
                                           weakSelf.currentConsumptionThreshold = kThresholdStrict;
                                       }
                                       else
                                       {
                                           // all's well, keep threshold lenient so
                                           // that we don't cut power prematurely
                                           weakSelf.isOverCurrent = NO;
                                           weakSelf.currentConsumptionThreshold = kThresholdLenient;
                                       }
                                   }];
}

@end
