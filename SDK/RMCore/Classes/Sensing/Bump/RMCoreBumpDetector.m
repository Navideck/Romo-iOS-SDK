//
//  RMCoreBumpDetector.m
//  RMCore
//

#import "RMCoreBumpDetector.h"
#import <RMShared/RMDispatchTimer.h>

@interface RMCoreBumpDetector()

@property (nonatomic, strong) RMDispatchTimer *senseLoop;  // sensing loop trigger
@property (nonatomic) BOOL pitchBumpDetected;              // sensing mode 1
@property (nonatomic) BOOL rotationBumpDetected;           // sensing mode 2
@property (nonatomic) BOOL bumpDetected;                   // fused detector status

@end


@implementation RMCoreBumpDetector

#pragma  mark - Setup

- (void)dealloc
{
    // stop sensing loop trigger
    [self.senseLoop stopRunning];
}

- (id)init
{
    self = [super init];
    if(!self) {return nil;}
    
    // set up sensing loop and start sensor
    _senseLoop = [[RMDispatchTimer alloc]
                  initWithName:@"com.romotive.bumpDetector"
                  frequency:UPDATE_FREQUENCY ];
                  
    __weak RMCoreBumpDetector *weakSelf = self;
    
    _senseLoop.eventHandler = ^{
        [weakSelf updateSensor];
    };
                  
    [self.senseLoop startRunning];
    
    return self;
}

- (void)setRobot:robot

// Provide access to robot's hardware
{
    _robot = robot;
}

#pragma mark - Loop

// Detect if robot has bumped into an obstacle
- (void)updateSensor
{
    [self pitchUpDetect];
    [self unexpectedRotationDetect];
    
    if(self.pitchBumpDetected || self.rotationBumpDetected)
    {
        if(self.bumpDetected == NO)
        {
            self.bumpDetected = YES;
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"RMBumpDetected" object:nil ];
        }
    }
    else
    {
        if(self.bumpDetected == YES)
        {
            self.bumpDetected = NO;
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"RMBumpCleared" object:nil ];
        }
        
    }
}

#pragma  mark - Detection Routines

- (void)pitchUpDetect
{
    const float kNoBumpPitch = 10.;                        // degrees
    
    float bumpPitch;                                       // degrees
    float pitch = -self.robot.platformAttitude.pitch;      // degrees
    
    // adjust trigger pitch based on drive speed (momentum and all that jazz...)
    // (note: these numbers were picked out of thin air and may need adjusting)
    if(self.robot.speed < .2)       // m/s
    {                               //
        bumpPitch = 35;             // degrees
    }                               //
    else if(self.robot.speed < .4)  // m/s
    {                               //
        bumpPitch = 30;             // degrees
    }                               //
    else if(self.robot.speed < .6)  // m/s
    {                               //
        bumpPitch = 15;             // degress
    }                               //
    else                            //
    {                               //
        bumpPitch = 5;              // degrees
    }                               //
    
    if(pitch > bumpPitch)
    {
        self.pitchBumpDetected = YES;
    }
    else if(pitch < kNoBumpPitch)
    {
        self.pitchBumpDetected = NO;
    }
}

- (void)unexpectedRotationDetect
{
    const float kMaxYawRate = 100.;
    
    // this detection technique depends on the assumption that the robot is
    // supposed to be driving straight, with minimal rotation, which can be
    // expected when the drive commanded is forward or backward (which in RMCore
    // mean straight forward or straight backward)
    if(self.robot.driveCommand == RMCoreDriveCommandForward ||
       self.robot.driveCommand == RMCoreDriveCommandBackward )
    {
        if(fabsf(self.robot.platformYawRate) > kMaxYawRate)
        {
            self.rotationBumpDetected = YES;
        }
        else
        {
            self.rotationBumpDetected = NO;
        }
    }
    else
    {
        // if the drive command is no longer straight there's no way for this
        // virtual sensor to make a decission, so we have to assume everything's
        // fine
        self.rotationBumpDetected = NO;
    }
}

@end