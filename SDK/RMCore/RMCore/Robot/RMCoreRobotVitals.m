//
//  RMCoreRobotVitals.m
//  RMCore
//

#import "RMCoreRobotVitals.h"
#import "RMCoreRobot_Internal.h"
#import "RMCoreRobotCommunication.h"
#import <RMShared/RMMath.h>

#define BATTERY_FULL                860     // 5.589V
#define BATTERY_EMPTY               685     // 4.3V

static const int kMaxBatteryStatusesToAverage = 5;

@interface RMCoreRobotVitals() {

    NSMutableArray *_batteryStatusesToAverage;
}

@property (nonatomic, weak) RMCoreRobot *robot;

@end

@implementation RMCoreRobotVitals

@synthesize charging = _charging;
@synthesize batteryLevel = _batteryLevel;

- (id)initWithRobot:(RMCoreRobot *)robot
{
    self = [super init];
    _robot = robot;
    if (self) {
        _batteryStatusesToAverage = [NSMutableArray new];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveVitals)
                                                 name:RMCoreRobotCommunicationVitalsUpdateNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - RMCoreRobotVitalsDelegate methods

- (void)didReceiveVitals
{
    // Keep a rolling average of battery statuses (as ADC values) to smooth out bumps
    [_batteryStatusesToAverage addObject:[NSNumber numberWithUnsignedInt:self.robot.communication.batteryStatus]];
    
    if (_batteryStatusesToAverage.count > kMaxBatteryStatusesToAverage) {
        [_batteryStatusesToAverage removeObjectAtIndex:0];
    }
    
    NSNumber *sum = [_batteryStatusesToAverage valueForKeyPath:@"@sum.self"];
    float average = sum.floatValue / _batteryStatusesToAverage.count;
    
    float normalized = (float)(average-BATTERY_EMPTY)/(float)(BATTERY_FULL-BATTERY_EMPTY);
    _batteryLevel = CLAMP(0.0, normalized, 1.0);
    _charging = (self.robot.communication.chargingState == RMChargingStateOn);
}

@end
