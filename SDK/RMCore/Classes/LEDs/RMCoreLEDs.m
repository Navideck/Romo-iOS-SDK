//
//  RMCoreLEDs.m
//  RMCore
//

#import "RMCoreLEDs_Internal.h"
#import "RMCoreRobotCommunication.h"
#import "RMCoreRobot.h"
#import "RMCoreRobot_Internal.h"
#import <RMShared/RMMath.h>

@implementation RMCoreLEDs

#pragma mark - Initialization

- (RMCoreLEDs *)initWithPwmScalar:(unsigned int)pwmScalar
{
    self = [super init];
    if (self) {
        _mode = RMCoreLEDModeOff;
        _brightness = 1.0f;
        _period = 2.0f;
        _dutyCycle = 0.5f;
        _pulseDirection = RMCoreLEDPulseDirectionUpAndDown;
        
        _pwmScalar = pwmScalar;
    }
    return self;
}

- (void)setSolidWithBrightness:(float)brightness
{
    _mode = RMCoreLEDModeSolid;
    _brightness = CLAMP(0.0, brightness, 1.0);

    [self.robot.communication setLEDNumber:0 pwm:(self.brightness * self.pwmScalar)];
}

- (void)turnOff
{
    _mode = RMCoreLEDModeOff;
    [self.robot.communication setLEDNumber:0 mode:RMLedModeOff];
}
     
- (void)blinkWithPeriod:(float)period dutyCycle:(float)dutyCycle
{
    [self blinkWithPeriod:period dutyCycle:dutyCycle brightness:1.0];
}

- (void)blinkWithPeriod:(float)period dutyCycle:(float)dutyCycle brightness:(float)brightness
{
    _mode = RMCoreLEDModeBlink;
    dutyCycle = CLAMP(0.05, dutyCycle, 0.95);
    _dutyCycle = dutyCycle;
    
    // Check firmware capabilities
    if (self.robot.communication.supportsLongBlinks) {
        // Newer firmware supports long blinks and variable brightness
        period = CLAMP(0.05, period, 60.0);
        _period = period;
        _brightness = CLAMP(0.0, brightness, 1.0);
    } else {
        // Old firmware is limited to 1s period and full brightness,
        // and uses incorrect math for blink rates (compensate here).
        period = CLAMP(0.05, period, 1.0);
        _period = 3.0f/2.0f * period;
        _brightness = 1.0;
    }
    
    [self.robot.communication setLEDNumber:0
                               blinkOnTime:self.period * 1000.0 * self.dutyCycle
                              blinkOffTime:self.period * 1000.0 * (1.0 - self.dutyCycle)
                                       pwm:self.brightness * self.pwmScalar];
}

- (void)pulseWithPeriod:(float)period direction:(RMCoreLEDPulseDirection)direction
{
    period = CLAMP(0.05, period, 9.5);
    
    // Find parameters with lowest error
    // Trigger = [1,7] (above 7 can result in choppy pulsing)
    // Step = Trigger/period_in_seconds * 2.7962s
    // Note: Half-pulse has half period, so double the desired period for calculating
    int halfPulseScalar = (direction == RMCoreLEDPulseDirectionUpAndDown) ? 1 : 2;
    int trigger = 0;
    int step = 0;
    float lowestError = MAXFLOAT;
    for(int t=1; t<=7; t++) {
        // Calculate step and round to nearest int
        int s = (t * 2.7962f / (period * halfPulseScalar)) + 0.5f;
        if (s >= 1) {
            // Calculate actual period from t and s
            float p = t * 2.7962f / (s * halfPulseScalar);
            // Compare to lowestError to find best values
            float error = ABS(period - p) / period;
            if (error < lowestError) {
                lowestError = error;
                trigger = t;
                step = s;
            }
        }
    }
    
    // Check for success
    if (trigger && step) {
        _mode = RMCoreLEDModePulse;
        _period = period;
        _pulseDirection = direction;
        
        // Set the mode
        switch(_pulseDirection) {
            case RMCoreLEDPulseDirectionUpAndDown:
                [self.robot.communication setLEDNumber:0 pulseTrigger:trigger pulseCount:step];
                break;
                
            case RMCoreLEDPulseDirectionUp:
                [self.robot.communication setLEDNumber:0 halfPulseUpTrigger:trigger halfPulseUpCount:step];
                break;
                
            case RMCoreLEDPulseDirectionDown:
                [self.robot.communication setLEDNumber:0 halfPulseDownTrigger:trigger halfPulseDownCount:step];
                break;
                
            default:
                break;
        }
    }
}

@end
