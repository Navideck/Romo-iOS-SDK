//
//  RMCoreRobotCommunicationOld.m
//  RMCore
//

#import "RMCoreRobotCommunicationOld.h"
#import <UIKit/UIKit.h>
#import <RMshared/RMShared.h>
#import "RMCore.h"

//#define RPDEBUG                                   // Turn on RMCoreRobotCommunicationOld Debugging (NSLogs)

static bool kUseWatchdog = YES;
static const float kSendRate = 0.05;              // 20Hz send rate for all commands
static const float kHeartbeatRateMin = 0.25f;     // Min time between heartbeat commands
//static const float kHeartbeatRateMax = 2.0f;      // Max time between heartbeat commands
static const float kDeadRobotTimeout = 4.0f;      // Timeout for command acks (robot stopped responding)
//static const float kOtherCommandRateMax = 1.0f;   // Max time between "other" commands
//static const float kAckTimeout = 0.5f;

@interface RMCoreRobotCommunicationOld () <RobotCommunicationProtocol, RMCoreRobotDataTransportDelegate>

@property (nonatomic, readwrite, weak) RMCoreRobotDataTransport *transport;
@property (nonatomic, strong) NSMutableArray *otherCommands;
@property (nonatomic, strong) RMDispatchTimer *communicationTimer;
@property (nonatomic) uint8_t watchdogN;

@property (nonatomic) RMLedMode ledMode;
@property (nonatomic) uint8_t ledPwm;
@property (nonatomic) uint16_t ledBlinkOnDelay;
@property (nonatomic) uint16_t ledBlinkOffDelay;
@property (nonatomic) uint8_t ledPulseTrigger;
@property (nonatomic) uint8_t ledPulseStep;
@property (nonatomic) int16_t motorValueLeft;
@property (nonatomic) int16_t motorValueRight;
@property (nonatomic) int16_t motorValueTilt;
@property (nonatomic) BOOL justConnected;
@property (nonatomic) BOOL hasNewMotorCommand;
@property (nonatomic) BOOL hasNewLEDCommand;
@property (nonatomic) int ticksSinceLastHeartbeat;
@property (nonatomic) int ticksSinceLastResponse;
@property (nonatomic) int ticksSinceLastOtherCommand;
@property (nonatomic) int ticksSinceLastAck;

@property (nonatomic, readwrite) uint16_t motorCurrentLeft;
@property (nonatomic, readwrite) uint16_t motorCurrentRight;
@property (nonatomic, readwrite) uint16_t motorCurrentTilt;
@property (nonatomic, readwrite) uint16_t batteryStatus;
@property (nonatomic, readwrite) RMChargingState chargingState;

@end

@implementation RMCoreRobotCommunicationOld

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
    if (self) {
        self.transport = transport;
        self.transport.transportDelegate = self;
        
        if (transport) {
            _otherCommands = [NSMutableArray array];
            
            // Set defaults
            _deviceMode = RMDeviceModeRun;
            _ledMode = RMLedModeOff;
            _ledPwm = 255;
            _ledBlinkOnDelay = 250;
            _ledBlinkOffDelay = 250;
            _ledPulseTrigger = 1;
            _ledPulseStep = 2;
            _supportsLongBlinks = NO;
            _supportsEvents = YES;
            _supportsReset = NO;
            [self enableWatchdog];
            
            __weak RMCoreRobotCommunicationOld *weakSelf = self;
            self.transport.disconnectCompletion = ^(RMCoreRobotDataTransport *transport, BOOL disconnected){
                // First, ensure the communicationQueue is shutdown and not sending more commands
                if (weakSelf.communicationTimer.queue) {
                    dispatch_sync(weakSelf.communicationTimer.queue, ^{
                        [weakSelf suspendCommunication];
                    });
                }
            };
            
            _justConnected = YES;
            
            _ledMode = RMLedModePWM;
            _ledPwm = 255;
            _hasNewLEDCommand = YES;
            
            [self.communicationTimer startRunning];
        }
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.communicationTimer stopRunning];
}

#pragma mark - RobotCommunicationProtocol

- (void)softReset
{
    // suspend the communication here so we don't send control commands
    // a new communication will be created when the robot reconnects
    [self suspendCommunication];
    [self.transport softReset];
}

- (void)suspendCommunication
{
    [self.communicationTimer stopRunning];
}

- (uint16_t)requestMotorCurrent:(RMCoreMotorAxis)motor
{
    [self queueCommand:CMD_GET_MOTOR_CURRENT];
    switch((Romo3MotorAxis)motor) {
        case Romo3MotorAxisLeft: return self.motorCurrentLeft;
        case Romo3MotorAxisRight: return self.motorCurrentRight;
        case Romo3MotorAxisTilt: return self.motorCurrentTilt;
        case Romo3MotorAxisNull:
        default: return NAN;
    }
}

- (void)requestInfoType:(RMInfoType)type
{
    [self requestInfoType:type index:0 destination:nil];
}

- (void)requestInfoType:(RMInfoType)type index:(unsigned char)index
{
    [self requestInfoType:type index:index destination:nil];
}

- (void)requestInfoType:(RMInfoType)type destination:(id)destination
{
    [self requestInfoType:type index:0 destination:destination];
}

- (void)requestInfoType:(RMInfoType)type index:(unsigned char)index destination:(id)destination
{
    switch(type) {
        case RMInfoTypeMotorCurrent:
            [self queueCommand:CMD_GET_MOTOR_CURRENT];
            break;
            
        case RMInfoTypeMotorPWM:
        case RMInfoTypeMotorVelocity:
        case RMInfoTypeMotorPosition:
        case RMInfoTypeMotorTemp:
        case RMInfoTypeMotorTorque:
        case RMInfoTypeNull:
        default:
            break;
    }
}

- (void)requestBatteryStatus
{
    [self queueCommand:CMD_GET_BATTERY_STATUS];
}

- (void)requestChargingState
{
    [self queueCommand:CMD_GET_CHARGING_STATE];
}

- (void)requestVitals
{
    [self queueCommand:CMD_GET_VITALS];
}

- (void)writeEEPROMAddress:(unsigned short int)address
                    length:(unsigned char)length
                      data:(NSData *)data
{
    
}

- (void)readEEPROMAddress:(unsigned short int)address
                   length:(unsigned char)length
{
    
}

- (void)setDeviceMode:(RMDeviceMode)deviceMode
{
    _deviceMode = deviceMode;
    [self queueCommand:CMD_SET_MODE];
}

- (void)setMotorNumber:(RMCoreMotorAxis)motor
           commandType:(RMMotorCommandType)type
                 value:(short int)value
{
    dispatch_async(self.communicationTimer.queue, ^{
        switch(motor) {
            case Romo3MotorAxisLeft:
                self.motorValueLeft = value;
                break;
                
            case Romo3MotorAxisRight:
                self.motorValueRight = value;
                break;
                
            case Romo3MotorAxisTilt:
                self.motorValueTilt = value;
                break;
                
            case Romo3MotorAxisNull:
                break;
        }
        self.hasNewMotorCommand = YES;
    });
}

- (void)setLEDNumber:(unsigned char)led
                 pwm:(unsigned char)pwm
{
    dispatch_async(self.communicationTimer.queue, ^{
        self.ledMode = RMLedModePWM;
        self.ledPwm = pwm;
        self.hasNewLEDCommand = YES;
    });
}

- (void)setLEDNumber:(unsigned char)led
         blinkOnTime:(unsigned short int)onTime
        blinkOffTime:(unsigned short int)offTime
                 pwm:(unsigned char)pwm
{
    dispatch_async(self.communicationTimer.queue, ^{
        self.ledMode = RMLedModeBlink;
        self.ledBlinkOffDelay = offTime;
        self.ledBlinkOnDelay = onTime;
        self.hasNewLEDCommand = YES;
    });
}

- (void)setLEDNumber:(unsigned char)led
        pulseTrigger:(unsigned char)trigger
          pulseCount:(unsigned char)count
{
    dispatch_async(self.communicationTimer.queue, ^{
        self.ledMode = RMLedModePulse;
        self.ledPulseTrigger = trigger;
        self.ledPulseStep = count;
        self.hasNewLEDCommand = YES;
    });
}

- (void)setLEDNumber:(unsigned char)led
  halfPulseUpTrigger:(unsigned char)trigger
    halfPulseUpCount:(unsigned char)count
{
    dispatch_async(self.communicationTimer.queue, ^{
        self.ledMode = RMLedModeHalfPulseUp;
        self.ledPulseTrigger = trigger;
        self.ledPulseStep = count;
        self.hasNewLEDCommand = YES;
    });
}

- (void)setLEDNumber:(unsigned char)led
halfPulseDownTrigger:(unsigned char)trigger
  halfPulseDownCount:(unsigned char)count
{
    dispatch_async(self.communicationTimer.queue, ^{
        self.ledMode = RMLedModeHalfPulseDown;
        self.ledPulseTrigger = trigger;
        self.ledPulseStep = count;
        self.hasNewLEDCommand = YES;
    });
}

- (void)setLEDNumber:(unsigned char)led
                mode:(RMLedMode)mode
{
    dispatch_async(self.communicationTimer.queue, ^{
        self.ledMode = mode;
        self.hasNewLEDCommand = YES;
    });
}

- (void)setiDeviceChargeEnable:(BOOL)enable
{
    uint8_t cmd[] = {CMD_SET_DEV_CHARGE_ENABLE, 1, enable};
    [self queueBytes:cmd length:sizeof(cmd)];
}

- (void)setiDeviceChargeCurrent:(unsigned short int)current
{
    uint8_t cmd[] = {CMD_SET_DEV_CHARGE_CURRENT, 2, (uint8_t)(current >> 8), (uint8_t)current};
    [self queueBytes:cmd length:sizeof(cmd)];
}

- (void)enableWatchdog
{
    //    [self.transport setWatchdogNValueForRate:4000];
    //    [self.transport setWatchdogNValueForRate:2*kHeartbeatRateMin];
    [self.transport setWatchdog:6]; // 6 = 500ms
}


- (void)disableWatchdog
{
    [self.transport disableWatchdog];
}

#pragma mark - RMCoreRobotDataTransportDelegate

- (void)didReceiveAckForCommand:(RMCommandToRobot)command data:(NSData *)data
{
    NSRange r;
    r.location = 0;
    r.length = [data length];
    
    //    self.waitingForAck = NO;
    self.ticksSinceLastAck = 0;
    
    if (r.length > 0) {
        uint8_t buf[CMD_MAX_PAYLOAD];
        [data getBytes:buf range:r];
        
        switch(command) {
            case CMD_GET_VITALS:
                if (r.length == 3) {
                    self.batteryStatus = (uint16_t)(buf[0]<<8) + buf[1];
                    self.chargingState = buf[2];
                    [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotCommunicationVitalsUpdateNotification
                                                                        object:nil
                                                                      userInfo:nil];
                }
                break;
                
            case CMD_GET_MOTOR_CURRENT:
                if (r.length == 6) {
                    self.motorCurrentLeft = (uint16_t)(buf[0]<<8) + buf[1];
                    self.motorCurrentRight = (uint16_t)(buf[2]<<8) + buf[3];
                    self.motorCurrentTilt = (uint16_t)(buf[4]<<8) + buf[5];
                    [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotCommunicationVitalsUpdateNotification
                                                                        object:nil
                                                                      userInfo:nil];
                }
                break;
                
            case CMD_GET_BATTERY_STATUS:
                if (r.length == 2) {
                    self.batteryStatus = (uint16_t)(buf[0]<<8) + buf[1];
                }
                break;
                
            case CMD_GET_CHARGING_STATE:
                if (r.length == 1) {
                    self.chargingState = buf[1];
                }
                break;
                
            default:
                break;
        }
    }
    self.ticksSinceLastResponse = 0;
}

- (void)didReceiveEvent:(RMAsyncEventType)event data:(NSData *)data
{
    switch(event) {
        case RMAsyncEventTypeHeartbeat:
            break;
        case RMAsyncEventTypeNull:
        default:
            break;
    }
}

#pragma mark - Private Methods

- (void)communicate
{
    if (self.communicationTimer.isRunning) {
        if (self.justConnected) {
            if (kUseWatchdog) {
                // Set watchdog timer on robot to expect heartbeat
                [self enableWatchdog];
            }
            self.justConnected = NO;
        } else {
            uint8_t buffer[CMD_MAX_PAYLOAD];
            bzero(buffer, sizeof(buffer));
            self.ticksSinceLastHeartbeat++;
            self.ticksSinceLastResponse++;
            self.ticksSinceLastOtherCommand++;
            self.ticksSinceLastAck++;
            
            // Don't wait forever for an Ack
            //            if ((self.ticksSinceLastAck * kSendRate) >= kAckTimeout) {
            //                self.waitingForAck = NO;
            //            }
            
            // Check if hearbeat sending has reached max limit
            if (self.hasNewMotorCommand) {
                // Send motor command
                buffer[0] = CMD_SET_MOTORS;
                buffer[1] = 6;                                  // Payload length
                buffer[2] = (uint8_t)(_motorValueLeft>>8);      // High byte
                buffer[3] = (uint8_t)_motorValueLeft;           // Low byte
                buffer[4] = (uint8_t)(_motorValueRight>>8);
                buffer[5] = (uint8_t)_motorValueRight;
                buffer[6] = (uint8_t)(_motorValueTilt>>8);
                buffer[7] = (uint8_t)_motorValueTilt;
                [self queueBytes:buffer length:8];
                self.hasNewMotorCommand = NO;
            } else if (self.hasNewLEDCommand) {
                // Send LED command
                switch(self.ledMode) {
                    case RMLedModeOff:
                        buffer[0] = CMD_SET_LEDS_OFF;
                        buffer[1] = 0;
                        break;
                    case RMLedModePWM:
                        buffer[0] = CMD_SET_LEDS_PWM;
                        buffer[1] = 1;
                        buffer[2] = _ledPwm;
                        break;
                    case RMLedModeBlink:
                        buffer[0] = CMD_SET_LEDS_BLINK;
                        buffer[1] = 4;
                        buffer[2] = (uint8_t)(_ledBlinkOnDelay>>8);
                        buffer[3] = (uint8_t)_ledBlinkOnDelay;
                        buffer[4] = (uint8_t)(_ledBlinkOffDelay>>8);
                        buffer[5] = (uint8_t)_ledBlinkOffDelay;
                        break;
                    case RMLedModePulse:
                        buffer[0] = CMD_SET_LEDS_PULSE;
                        buffer[1] = 2;
                        buffer[2] = _ledPulseTrigger;
                        buffer[3] = _ledPulseStep;
                        break;
                    case RMLedModeHalfPulseUp:
                        buffer[0] = CMD_SET_LEDS_HALFPULSEUP;
                        buffer[1] = 2;
                        buffer[2] = _ledPulseTrigger;
                        buffer[3] = _ledPulseStep;
                        break;
                    case RMLedModeHalfPulseDown:
                        buffer[0] = CMD_SET_LEDS_HALFPULSEDOWN;
                        buffer[1] = 2;
                        buffer[2] = _ledPulseTrigger;
                        buffer[3] = _ledPulseStep;
                        break;
                    default:
                        break;
                }
                [self queueBytes:buffer length:2+buffer[1]];
                self.hasNewLEDCommand = NO;
            } else if ([self.otherCommands count] > 0) {
                [self queueOtherCommand];
            } else if ((self.ticksSinceLastHeartbeat * kSendRate) >= kHeartbeatRateMin) {
                // If it's been at least min limit, send heartbeat
                [self queueHeartBeat];
            }
            
            // Check time since last heartbeat ack to detect dead robot
            if ((self.ticksSinceLastResponse * kSendRate) >= kDeadRobotTimeout) {
                //                NSLog(@"Timeout reached. No ack in %0.1f ms.",self.ticksSinceLastResponse * kSendRate * 1000);
                /* CURRENTLY TRIGGERS DUE TO MAIN THREAD BLOCKING RECEIVING
                 // Send soft reset
                 uint8_t request[] = {CMD_SOFT_RESET,0};
                 @synchronized (self)
                 {
                 [self queueTxBytes:[NSData dataWithBytes:request length:sizeof(request)]];
                 }
                 
                 // Call delegate method
                 if ([_delegate respondsToSelector:@selector(lostContactWithRobot)]) {
                 // Call delegate method back in main queue
                 dispatch_async(dispatch_get_main_queue(), ^{
                 [_delegate lostContactWithRobot];
                 });
                 }
                 */
                // Reset counter so we don't timeout constantly
                self.ticksSinceLastResponse = 0;
            }
        } // (useWatchdog && _justConnected)
    } // !isSuspended
}

- (void)queueCommand:(uint8_t)command
{
    dispatch_async(self.communicationTimer.queue, ^{
        [self.otherCommands addObject:@(command)];
    });
}

- (void)queueBytes:(uint8_t *)bytes length:(uint8_t)length
{
    [self.transport queueTxBytes:[NSData dataWithBytes:bytes length:length]];
}

- (void)queueHeartBeat
{
    uint8_t cmd[] = {CMD_GET_VITALS, 0};
    [self queueBytes:cmd length:sizeof(cmd)];
    self.ticksSinceLastHeartbeat = 0;
}

- (void)queueOtherCommand
{
    dispatch_async(self.communicationTimer.queue, ^{
        uint8_t buffer[CMD_MAX_PAYLOAD];
        bzero(buffer, sizeof(buffer));
        
        // Send next waiting command
        if ([self.otherCommands count] > 0) {
            uint8_t command = [self.otherCommands[0] unsignedCharValue];
            [self.otherCommands removeObjectAtIndex:0];
            buffer[0] = command;
            switch(command) {
                case CMD_SET_MODE:
                    buffer[1] = 1;                      //Length of payload
                    buffer[2] = (uint8_t)self.deviceMode;
                    break;
                case CMD_SET_WATCHDOG:
                    buffer[1] = 1;                      //Length of payload
                    buffer[2] = self.watchdogN;
                    break;
                    // All other commands will send with no parameters
                case CMD_DISABLE_WATCHDOG:
                case CMD_GET_MOTOR_CURRENT:
                case CMD_GET_BATTERY_STATUS:
                case CMD_GET_CHARGING_STATE:
                case CMD_SOFT_RESET:
                case STK_LEAVE_PROGMODE:
                default:
                    buffer[1] = 0;
                    break;
            }
            [self queueBytes:buffer length:2+buffer[1]];
            self.ticksSinceLastOtherCommand = 0;
        }
    });
}

- (RMDispatchTimer *)communicationTimer
{
    if (!_communicationTimer) {
        __weak RMCoreRobotCommunicationOld *weakSelf = self;
        _communicationTimer = [[RMDispatchTimer alloc] initWithName:@"com.romotive.robotCommunicationQueue" frequency:(1.0 / kSendRate)];
        _communicationTimer.eventHandler = ^{
            [weakSelf communicate];
        };
    }
    return _communicationTimer;
}

@end
