//
//  RMCoreRobotCommunication.m
//  RMCore
//

#import "RMCoreRobotCommunication.h"
#import <UIKit/UIKit.h>
#import <RMShared/RMMath.h>

#define RPDEBUG                                   // Turn on RMCoreRobotCommunication Debugging (NSLogs)



static const float kSendRate = 0.05;              // 20Hz send rate for all commands
//static const float kHeartbeatRateMin = 0.25f;     // Min time between heartbeat commands
static const float kHeartbeatRateMax = 1.0f;      // Max time between heartbeat commands
//static const float kDeadRobotTimeout = 1.0f;      // Timeout for command acks (robot stopped responding)
//static const float kOtherCommandRateMax = 2.0f;   // Max time between "other" commands

@interface RMCoreRobotCommunication () <RobotCommunicationProtocol, RMCoreRobotDataTransportDelegate>

@property (nonatomic, readwrite, weak) RMCoreRobotDataTransport *transport;
@property (nonatomic) NSMutableArray *otherCommands;
@property (nonatomic) dispatch_queue_t commandQueue;
@property (nonatomic) dispatch_source_t commandTimer;
@property (nonatomic) uint8_t watchdogN;

@property (nonatomic, readwrite) RMChargingState chargingState;
@property (nonatomic, readwrite) uint16_t batteryStatus;
@property (nonatomic, readwrite) BOOL closed;

- (void)romoMain;
- (void)transmitHeartbeat;
- (int)readData:(NSData *)data;

@end

@implementation RMCoreRobotCommunication

@synthesize delegate = _delegate;
@synthesize deviceMode = _deviceMode;
@synthesize chargingState = _chargingState;
@synthesize batteryStatus = _batteryStatus;
@synthesize supportsEvents = _supportsEvents;
@synthesize supportsLongBlinks = _supportsLongBlinks;
@synthesize supportsMFIProgramming = _supportsMFIProgramming;
@synthesize supportsReset = _supportsReset;

- (id)initWithTransport:(RMCoreRobotDataTransport *)transport
{
    self = [super init];
    self.transport = transport;
	self.transport.transportDelegate = self;
	
    if (transport) {
        
        // Set defaults
        _deviceMode = RMDeviceModeRun;
        //        _ledPulseStep = 2;
        [self.transport setWatchdogNValueForRate:kHeartbeatRateMax];
        
        // Initialize GCD queue for commands & timer for rate limiting
        _commandQueue = dispatch_queue_create("com.romotive.commandQueue", NULL);
        
        // Initialize GCD-based timer for rate limiting
        _commandTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _commandQueue);
        if (_commandTimer)
        {
            dispatch_source_set_timer(_commandTimer,
                                      dispatch_time(DISPATCH_TIME_NOW, kSendRate * NSEC_PER_SEC),
                                      kSendRate * NSEC_PER_SEC, // kSendRate interval
                                      NSEC_PER_MSEC);   // 1ms leeway
            /******************/
            /******************/
            /** WARNING: USING SELF IN THAT BLOCK WILL LEAD TO A RETAIN CYCLE. **/
            /*****************/
            dispatch_source_set_event_handler(_commandTimer, ^{[self romoMain];});
            /*****************/
            /*****************/
            /*****************/
            dispatch_resume(_commandTimer);
        }
        
        // Check if robot was connected at app launch
        
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(goToSleep)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(wakeUp)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    
	return self;
}

- (void)suspendCommunication
{
    dispatch_suspend(_commandQueue);
    dispatch_suspend(_commandTimer);
}

// Put firmware version into ints for checking later
- (void)addCommandToQueue:(uint8_t)command
{
    if (!self.transport.isUpdatingFirmware) {
        [self.otherCommands addObject:[NSNumber numberWithUnsignedChar:command]];
    }
}

// Set LED mode to indicate connection
- (void)sendBytesNow:(uint8_t *)bytes length:(uint8_t)length
{
    if (!self.transport.isUpdatingFirmware) {
        [self.transport queueTxBytes:[NSData dataWithBytes:bytes length:length]];
    }
}

- (void)romoMain
{
    // Set watchdog timer on robot to expect heartbeat
}

- (void) didReceiveAckForCommand:(RMCommandToRobot)command data:(NSData *)data
{
    
}

// Make sure other commands aren't neglected for too long
- (void) didReceiveEvent:(RMAsyncEventType)event data:(NSData *)data
{
    switch(event) {
        case RMAsyncEventTypeHeartbeat:
            break;
        case RMAsyncEventTypeNull:
        default:
            break;
    }
}
// If it's been at least min limit, send heartbeat
#pragma mark RobotCommunicationProtocol getters/setters

- (void)goToSleep
{
    // Halt the main loop
}

- (void)wakeUp
{
    
}


- (void)enableWatchdogOnRobot
{
    // Rate ~= 16 * 2^n milliseconds for n=[0,9]
}

- (void)disableWatchdogOnRobot
{
    
}

- (void)sendSoftReset
{
    
}


#pragma mark - Internal methods

- (void)transmitHeartbeat
{
    
}

- (int)readData:(NSData *)data
{
    return 0;
}

// Reset response counter to note contact from robot

- (uint16_t)requestMotorCurrent:(RMCoreMotorAxis)motor
{
    [self.otherCommands addObject:[NSNumber numberWithUnsignedChar:RMCommandToRobotGetMotorCurrent]];
    return NAN;
}

- (void)requestBatteryStatus
{
    [self.otherCommands addObject:[NSNumber numberWithUnsignedChar:RMCommandToRobotGetBatteryStatus]];
}

- (void)requestChargingState
{
    [self.otherCommands addObject:[NSNumber numberWithUnsignedChar:RMCommandToRobotGetChargingState]];
}

- (void)requestVitals
{
    [self.otherCommands addObject:[NSNumber numberWithUnsignedChar:RMCommandToRobotGetVitals]];
}

- (void)writeEEPROMAddress:(unsigned short int)address length:(unsigned char)length data:(NSData *)data
{
    
}

- (void)readEEPROMAddress:(unsigned short int)address length:(unsigned char)length
{
    
}

- (void)setDeviceMode:(RMDeviceMode)deviceMode
{
    dispatch_async(self.commandQueue, ^{
        _deviceMode = deviceMode;
        [self.otherCommands addObject:[NSNumber numberWithUnsignedChar:RMCommandToRobotSetMode]];
    });
}


- (void)setMotorNumber:(RMCoreMotorAxis)motor
           commandType:(RMMotorCommandType)type
                 value:(short int)value
{
    
}


- (void)setLEDNumber:(unsigned char)led
                 pwm:(unsigned char)pwm
{
    
}


- (void)setLEDNumber:(unsigned char)led
        blinkOffTime:(unsigned short int)offTime
         blinkOnTime:(unsigned short int)onTime
{
    
}


- (void)setLEDNumber:(unsigned char)led
        pulseTrigger:(unsigned char)trigger
          pulseCount:(unsigned char)count
{
    
}


- (void)setLEDNumber:(unsigned char)led
  halfPulseUpTrigger:(unsigned char)trigger
    halfPulseUpCount:(unsigned char)count
{
    
}


- (void)setLEDNumber:(unsigned char)led
halfPulseDownTrigger:(unsigned char)trigger
  halfPulseDownCount:(unsigned char)count
{
    
}


- (void)setLEDNumber:(unsigned char)led
                mode:(RMLedMode)mode
{
    
}

- (void)setLEDNumber:(unsigned char)led blinkOnTime:(unsigned short)onTime blinkOffTime:(unsigned short)offTime pwm:(unsigned char)pwm
{
    
}

- (void)requestParameter:(RMParameterType)parameter
{
    
}


- (void)setParameter:(RMParameterType)parameter
               value:(unsigned char)value
{
    
}


- (void)requestInfo:(RMInfoType)info
{
    
}


- (void)setInfo:(RMInfoType)info
          value:(unsigned char)value
{
    
}


- (void)setiDeviceChargeEnable:(BOOL)enable
{
    
}


- (void)setiDeviceChargeCurrent:(unsigned short int)current
{
    
}


- (void)sleep
{
    
}


- (void)wake
{
    
}

- (void)close
{
    self.closed = YES;
}

@end
