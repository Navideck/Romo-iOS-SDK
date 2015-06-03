//
//  RMCoreInertialStasis.m
//  RMCore
//

#import "RMCoreInertialStasis.h"
#import <RMShared/RMDispatchTimer.h>

@interface RMCoreInertialStasis()

@property (nonatomic, strong) RMDispatchTimer *senseLoop;// sensing loop trigger
@property (nonatomic) BOOL stasisDetected;               // detector status

@end


@implementation RMCoreInertialStasis

#pragma mark - Steup

- (void)dealloc
{
    // stop the sensing trigger
    [self.senseLoop stopRunning];
}

- (id)init
{
    self = [super init];
    if(!self) {return nil;}
    
    // set up sensing loop and start sensor
    _senseLoop = [[RMDispatchTimer alloc]
                  initWithName:@"com.romotive.inertialStasisDetector"
                  frequency:UPDATE_FREQUENCY ];
    
    __weak RMCoreInertialStasis *weakSelf = self;
    
    _senseLoop.eventHandler = ^{
        [weakSelf updateSensor];
    };

    _stasisDetected = NO;
    
    // NOTE: There is currently NO inertial stasis detection algorithm which is
    //       why the senseLoop is not being started.  I am leaving this module
    //       in place because at some point inertial stasis algorithm(s) should
    //       be added in here.
    //[self.senseLoop startRunning];
    
    return self;
}

// Provide access to robot's hardware
- (void)setRobot:robot
{
    _robot = robot;
}

#pragma  mark - Detector

// Detect when robot does not seem to be making substantial "forward" progess
- (void)updateSensor
{
    
    // TODO: Place future inertial stasis sensing algorithms here
    
}

// Notify stasis triggered
- (void)publishStasisTriggered
{
    self.stasisDetected = YES;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"RMInerialStasisDetected" object:nil ];
}

// Notify stasis cleared
- (void)publishStasisCleared
{
    self.stasisDetected = NO;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"RMInertialStasisCleared" object:nil ];
}

@end