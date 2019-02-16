//
//  RomoProtocol.m
//  RomoTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//

#import "RomoProtocol.h"

//#define RPDEBUG                                   // Turn on RomoProtocol Debugging (NSLogs)

static bool kUseWatchdog = NO;
static const float kSendRate = 0.05;              // 20Hz send rate for all commands
static const float kHeartbeatRateMin = 0.25f;     // Min time between heartbeat commands
static const float kHeartbeatRateMax = 1.0f;      // Max time between heartbeat commands
static const float kDeadRobotTimeout = 1.0f;      // Timeout for command acks (robot stopped responding)
static const float kOtherCommandRateMax = 2.0f;   // Max time between "other" commands

@interface RomoProtocol ()
{
    dispatch_queue_t _commandQueue;
    dispatch_source_t _commandTimer;
    
    bool _isAwake;
    bool _justConnected;
    bool _newMotorCommand;
    bool _newLedCommand;
    NSMutableArray *_otherCommands;
    
    int _ticksSinceLastHeartbeat;
    int _ticksSinceLastResponse;
    int _ticksSinceLastOtherCommand;
    
    uint8_t _fwMaj;
    uint8_t _fwMin;
    uint8_t _fwRev;
    uint8_t _watchdogN;
    
    uint16_t _last5BatteryStatuses[5];
}

@property (nonatomic,readwrite) uint16_t motorCurrentLeft;
@property (nonatomic,readwrite) uint16_t motorCurrentRight;
@property (nonatomic,readwrite) uint16_t motorCurrentTilt;
@property (nonatomic,readwrite) uint16_t batteryStatus;
@property (nonatomic,readwrite) CHG_STATE chargingState;

- (void)romoMain;
- (void)transmitHeartbeat;
- (void)transmitOtherCommand;
- (int)readData:(NSData *)data;

@end

static RomoProtocol *_shared;

@implementation RomoProtocol

+ (RomoProtocol *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[RomoProtocol alloc] init];
    });
    
    return _shared;
}

- (id)init
{
	if (self = [super initWithProtocol:@"com.romotive.romo"])
    {
        _isAwake = YES;
        _otherCommands = [NSMutableArray new];
        for (int i=0; i<5; i++) {
            _last5BatteryStatuses[i] = 0;
        }
        
        // Set defaults
        _deviceMode = DEV_MODE_RUN;
        _ledMode = LED_MODE_OFF;
        _ledPwm = 255;
        _ledBlinkOnDelay = 250;
        _ledBlinkOffDelay = 250;
        _ledPulseCnt = 1;
        _ledPulseStep = 2;
        [self setWatchdogNValueForRate:2*kHeartbeatRateMin];
        
        if (eas != nil) {
            // Device was connected at app launch
            _justConnected = YES;
            
            // Put firmware version into ints for checking later
            NSArray *fw = [eas.accessory.firmwareRevision componentsSeparatedByString:@"."];
            if ([fw count] == 3)
            {
                _fwMaj = [fw[0] integerValue];
                _fwMin = [fw[1] integerValue];
                _fwRev = [fw[2] integerValue];
            }
            // Enqueue get_trim command
            [self requestTrim];
            
            // Set LED mode to indicate connection
            self.ledMode = LED_MODE_NORMAL;
        }
        
        // Initialize GCD queue for commands
        _commandQueue = dispatch_queue_create("com.romotive.commandQueue", NULL);

        // Initialize GCD-based timer for rate limiting
        _commandTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _commandQueue);
        if (_commandTimer)
        {
            dispatch_source_set_timer(_commandTimer,
                                      dispatch_time(DISPATCH_TIME_NOW, kSendRate * NSEC_PER_SEC),
                                      kSendRate * NSEC_PER_SEC, // kSendRate interval
                                      NSEC_PER_MSEC);   // 1ms leeway
            dispatch_source_set_event_handler(_commandTimer, ^{[self romoMain];});
            dispatch_resume(_commandTimer);
        }
    }

	return self;
}

- (void)accessoryDidConnect:(NSNotification *)notification
{
    [super accessoryDidConnect:notification];
    
    _justConnected = YES;
    _ticksSinceLastResponse = 0;
    
    // Put firmware version into ints for checking later
    NSArray *fw = [[self firmwareRevision] componentsSeparatedByString:@"."];
    if ([fw count] == 3)
    {
        _fwMaj = [fw[0] integerValue];
        _fwMin = [fw[1] integerValue];
        _fwRev = [fw[2] integerValue];
    }
    
    // Enqueue get_trim command
    [self requestTrim];
    
    // Set LED mode to indicate connection
    _ledPwm = 255;
    self.ledMode = LED_MODE_NORMAL;
    
    if ([_delegate respondsToSelector:@selector(didConnectToRobot)]) {
        [_delegate didConnectToRobot];
    }
}

- (void)accessoryDidDisconnect:(NSNotification *)notification
{
    _justConnected = NO;
    if ([_delegate respondsToSelector:@selector(didDisconnectFromRobot)]) {
        [_delegate didDisconnectFromRobot];
    }
    [super accessoryDidDisconnect:notification];
}

//- (void)romoMain:(NSTimer *)timer
- (void)romoMain
{
    if (_isAwake && [self isConnected])
    {
        if (kUseWatchdog && _justConnected)
        {
            // Set watchdog timer on robot to expect heartbeat
            uint8_t setWatchdog[] = {CMD_SET_WATCHDOG, 1, _watchdogN};
            [self queueTxBytes:[NSData dataWithBytes:setWatchdog length:sizeof(setWatchdog)]];
            _justConnected = NO;
        }
        else
        {
            uint8_t buffer[CMD_MAX_PAYLOAD];
            bzero(buffer, sizeof(buffer));
            _ticksSinceLastHeartbeat++;
            _ticksSinceLastResponse++;
            _ticksSinceLastOtherCommand++;
            
            // Check if hearbeat sending has reached max limit
            if ((_ticksSinceLastHeartbeat * kSendRate) >= kHeartbeatRateMax)
            {
                // If so, must send heartbeat
                [self transmitHeartbeat];
            }
            else if (((_ticksSinceLastOtherCommand * kSendRate) >= kOtherCommandRateMax)
                     && ([_otherCommands count] > 0))
            {
                // Make sure other commands aren't neglected for too long
                [self transmitOtherCommand];
            }
            else if (_newMotorCommand)
            {
                // Send motor command
                buffer[0] = CMD_SET_MOTORS;
                buffer[1] = 6;                                  // Payload length
                buffer[2] = (uint8_t)(_motorValueLeft>>8);      // High byte
                buffer[3] = (uint8_t)_motorValueLeft;           // Low byte
                buffer[4] = (uint8_t)(_motorValueRight>>8);
                buffer[5] = (uint8_t)_motorValueRight;
                buffer[6] = (uint8_t)(_motorValueTilt>>8);
                buffer[7] = (uint8_t)_motorValueTilt;
                @synchronized (self)
                {
                    [self queueTxBytes:[NSData dataWithBytes:buffer length:8]];
                }
                _newMotorCommand = NO;
            }
            else if (_newLedCommand)
            {
                // Send LED command
                switch (_ledMode) {
                    case LED_MODE_OFF:
                        buffer[0] = CMD_SET_LEDS_OFF;
                        buffer[1] = 0;
                        break;
                    case LED_MODE_NORMAL:
                        buffer[0] = CMD_SET_LEDS_PWM;
                        buffer[1] = 1;
                        buffer[2] = _ledPwm;
                        break;
                    case LED_MODE_BLINK:
                        buffer[0] = CMD_SET_LEDS_BLINK;
                        buffer[1] = 4;
                        buffer[2] = (uint8_t)(_ledBlinkOnDelay>>8);
                        buffer[3] = (uint8_t)_ledBlinkOnDelay;
                        buffer[4] = (uint8_t)(_ledBlinkOffDelay>>8);
                        buffer[5] = (uint8_t)_ledBlinkOffDelay;
                        break;
                    case LED_MODE_PULSE:
                        buffer[0] = CMD_SET_LEDS_PULSE;
                        buffer[1] = 2;
                        buffer[2] = _ledPulseCnt;
                        buffer[3] = _ledPulseStep;
                        break;
                    case LED_MODE_HALFPULSEUP:
                        buffer[0] = CMD_SET_LEDS_HALFPULSEUP;
                        buffer[1] = 2;
                        buffer[2] = _ledPulseCnt;
                        buffer[3] = _ledPulseStep;
                        break;
                    case LED_MODE_HALFPULSEDOWN:
                        buffer[0] = CMD_SET_LEDS_HALFPULSEDOWN;
                        buffer[1] = 2;
                        buffer[2] = _ledPulseCnt;
                        buffer[3] = _ledPulseStep;
                        break;
                    default:
                        break;
                }
                @synchronized (self)
                {
                    [self queueTxBytes:[NSData dataWithBytes:buffer length:2+buffer[1]]];
                }
                _newLedCommand = NO;
            }
            else if ([_otherCommands count] > 0)
            {
                [self transmitOtherCommand];
            }
            else if ((_ticksSinceLastHeartbeat * kSendRate) >= kHeartbeatRateMin)
            {
                // If it's been at least min limit, send heartbeat
                [self transmitHeartbeat];
            }
            
            // Check time since last heartbeat ack to detect dead robot
            if ((_ticksSinceLastResponse * kSendRate) >= kDeadRobotTimeout)
            {
                NSLog(@"Timeout reached. No ack in %0.1f ms.",_ticksSinceLastResponse * kSendRate * 1000);
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
                _ticksSinceLastResponse = 0;
            }
        } // (useWatchdog && _justConnected)/else
    } // isAwake && isConnected
}

- (void)goToSleep
{
    NSLog(@"RomoProtocol -goToSleep");
    // Prepare the robot to lose contact with the app (e.g. app closure)
    
    // Halt the main loop
    _isAwake = NO;
    
    // Reset stored motor values
    _motorValueLeft = 0;
    _motorValueRight = 0;
    _motorValueTilt = 0;
    
    // Empty waiting command queue
    [_otherCommands removeAllObjects];
    
    // Send a single packet of commands to disable the watchdog, stop the motors, and turn off the LEDs
    uint8_t buffer[] = {CMD_DISABLE_WATCHDOG, 0,
        CMD_SET_MOTORS, 6, 0, 0, 0, 0, 0, 0,
        CMD_SET_LEDS_OFF, 0};
    @synchronized (self)
    {
        [self queueTxBytes:[NSData dataWithBytes:buffer length:sizeof(buffer)]];
    }
}

- (void)wakeUp
{
    NSLog(@"RomoProtocol -wakeUp");
    // Re-establish contact with the robot
    _ticksSinceLastResponse = 0;
    
    // Re-enable the watchdog timer on the robot
    if (kUseWatchdog)
        [self enableWatchdogOnRobot];
    
    // Set LEDs to last used state
    _newLedCommand = YES;
    
    // Kickstart the main loop
    _isAwake = YES;
}

#pragma mark - Custom setters

- (void)setDeviceMode:(DEV_MODE)deviceMode
{
    _deviceMode = deviceMode;
    [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_SET_MODE]];
}

- (void)setBatteryStatus:(uint16_t)batteryStatus
{
    // Average last 5 battery statuses
    int total = batteryStatus;
    int count = 1;
    for (int i=1; i<5; i++)                     // Skip the first one
    {
        if (_last5BatteryStatuses[i] > 0)
        {
            total += _last5BatteryStatuses[i];  // Add valid ones
            count++;                            // And count them
        }
    }
    
     _batteryStatus = total/count;
    if (_batteryStatus >= BATTERY_FULL)
        _batteryPercentage = 100;
    else if (_batteryStatus <= BATTERY_EMPTY)
        _batteryPercentage = 0;
    else
        _batteryPercentage = (((float)(_batteryStatus-BATTERY_EMPTY)/(BATTERY_FULL-BATTERY_EMPTY))*100.0 + 0.5); // Rounding
}

- (void)setLedMode:(LED_MODE)ledMode
{
    _ledMode = ledMode;
    _newLedCommand = YES;
}

- (void)setLedPwm:(uint8_t)ledPwm
{
    _ledPwm = ledPwm;
    _newLedCommand = YES;
}

- (void)setLedBlinkOnDelay:(uint16_t)ledBlinkOnDelay
{
    _ledBlinkOnDelay = ledBlinkOnDelay;
    _newLedCommand = YES;
}

- (void)setLedBlinkOffDelay:(uint16_t)ledBlinkOffDelay
{
    _ledBlinkOffDelay = ledBlinkOffDelay;
    _newLedCommand = YES;
}

- (void)setLedPulseCnt:(uint8_t)ledPulseCnt
{
    _ledPulseCnt = ledPulseCnt;
    _newLedCommand = YES;
}

- (void)setLedPulseStep:(uint8_t)ledPulseStep
{
    _ledPulseStep = ledPulseStep;
    _newLedCommand = YES;
}

- (void)setMotorValueLeft:(int16_t)motorValueLeft
{
    _motorValueLeft = motorValueLeft;
    _newMotorCommand = YES;
}

- (void)setMotorValueRight:(int16_t)motorValueRight
{
    _motorValueRight = motorValueRight;
    _newMotorCommand = YES;
}

- (void)setMotorValueTilt:(int16_t)motorValueTilt
{
    _motorValueTilt = motorValueTilt;
    _newMotorCommand = YES;
}

- (void)setTrimEnabledOnRobot:(bool)trimEnabledOnRobot
{
    _trimEnabledOnRobot = trimEnabledOnRobot;
    if (_trimEnabledOnRobot) {
        // Make sure the robot has current values
        [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_SET_TRIM_PWM]];
        [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_SET_TRIM_CURRENT]];
    }
    // Send flag state
    [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_SET_TRIM_FLAG]];
}


#pragma mark - Commands not sent by setters

- (void)sendTrimPwmValues
{
    [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_SET_TRIM_PWM]];
}

- (void)sendTrimCurrentValues
{
    [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_SET_TRIM_CURRENT]];
}

- (void)requestTrim
{
    [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_GET_TRIM]];
}

- (void)requestMotorCurrent
{
    [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_GET_MOTOR_CURRENT]];
}

- (void)requestBatteryStatus
{
    [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_GET_BATTERY_STATUS]];
}

- (void)requestChargingState
{
    [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_GET_CHARGING_STATE]];
}

// readEeprom

// writeEeprom


- (void)setWatchdogNValueForRate:(float)minRate
{
    // Rate ~= 16 * 2^n milliseconds for n=[0,9]
    uint8_t n = 0;
    while ((0.016f*pow(2,n)) <= minRate)
    {
        if (++n >= 9)
        {
            _watchdogN = 9;
            break;
        }
    }
    _watchdogN = n;
}

- (void)enableWatchdogOnRobot
{
    // Rate ~= 16 * 2^n milliseconds for n=[0,9]
    if (0 <= _watchdogN && _watchdogN <= 9) {
        [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_SET_WATCHDOG]];
#ifdef RPDEBUG
        NSLog(@"Enabling watchdog on robot with n = %d.",_watchdogN);
#endif
    }
    else
        NSLog(@"setWatchdog failed: n out of acceptable range.");
}

- (void)disableWatchdogOnRobot
{
    [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_DISABLE_WATCHDOG]];
}

- (void)sendSoftReset
{
    [_otherCommands addObject:[NSNumber numberWithUnsignedChar:CMD_SOFT_RESET]];
}


#pragma mark - Internal methods

- (void)transmitHeartbeat
{
    uint8_t buffer[CMD_MAX_PAYLOAD];
    bzero(buffer, sizeof(buffer));
    
    // Note: firmware versions before 0.0.9 don't support CMD_GET_VITALS
    if (_fwMaj == 0 && _fwMin == 0 && _fwRev <= 8)
        buffer[0] = CMD_GET_BATTERY_STATUS;
    else
        buffer[0] = CMD_GET_VITALS;
    buffer[1] = 0;
    @synchronized (self)
    {
        [self queueTxBytes:[NSData dataWithBytes:buffer length:2]];
    }
#ifdef RPDEBUG
    NSLog(@"Heartbeat sent.  %0.1f ms since last. %0.1f ms since last response.", _ticksSinceLastHeartbeat*kSendRate*1000,_ticksSinceLastResponse*kSendRate*1000);
#endif
    _ticksSinceLastHeartbeat = 0;
}

- (void)transmitOtherCommand
{
    uint8_t buffer[CMD_MAX_PAYLOAD];
    bzero(buffer, sizeof(buffer));
    
    // Send next waiting command
    if ([_otherCommands count] > 0)
    {
        uint8_t command = [_otherCommands[0] unsignedCharValue];
        [_otherCommands removeObjectAtIndex:0];
        buffer[0] = command;
        switch (command)
        {
            case CMD_SET_TRIM_PWM:
                buffer[1] = 4;                      //Length of payload
                buffer[2] = (uint8_t)(_trimLeftPwm>>8);     //Left trim high byte
                buffer[3] = (uint8_t)_trimLeftPwm;          //Left trim low byte
                buffer[4] = (uint8_t)(_trimRightPwm>>8);    //Right trim high byte
                buffer[5] = (uint8_t)_trimRightPwm;         //Right trim low byte
                break;
            case CMD_SET_TRIM_CURRENT:
                buffer[1] = 4;                      //Length of payload
                buffer[2] = (uint8_t)(_trimLeftCurrent>>8);     //Left trim high byte
                buffer[3] = (uint8_t)_trimLeftCurrent;          //Left trim low byte
                buffer[4] = (uint8_t)(_trimRightCurrent>>8);    //Right trim high byte
                buffer[5] = (uint8_t)_trimRightCurrent;         //Right trim low byte
                break;
            case CMD_SET_TRIM_FLAG:
                buffer[1] = 1;                      //Length of payload
                buffer[2] = (uint8_t)_trimEnabledOnRobot;         //Trim state
                break;
            //case CMD_READ_EEPROM:
                // Send address to read
            //case CMD_WRITE_EEPROM:
                // Send address to write along with data
            case CMD_SET_MODE:
                buffer[1] = 1;                      //Length of payload
                buffer[2] = (uint8_t)_deviceMode;
                break;
            case CMD_SET_WATCHDOG:
                buffer[1] = 1;                      //Length of payload
                buffer[2] = _watchdogN;
                break;
            // All other commands will send with no parameters
            case CMD_DISABLE_WATCHDOG:
            case CMD_GET_TRIM:
            case CMD_GET_MOTOR_CURRENT:
            case CMD_GET_BATTERY_STATUS:
            case CMD_GET_CHARGING_STATE:
            case CMD_SOFT_RESET:
            default:
                buffer[1] = 0;
                break;
        }
        @synchronized (self)
        {
            [self queueTxBytes:[NSData dataWithBytes:buffer length:2+buffer[1]]];
        }
        _ticksSinceLastOtherCommand = 0;
    }
}

- (int)readData:(NSData *)data
{
    // Raw data buffer coming in
	int ret;
	ret = 1;    // Always consume at least one byte so we don't hang
	if([data length] >= 2)
	{
        uint8_t cmdReceived;
        uint8_t payloadLength;
		NSRange r;
		uint8_t buf[CMD_MAX_PAYLOAD];
		r.location = 0;                         // location is at command received
		r.length = 1;
		[data getBytes:&cmdReceived range:r];
		r.location++;                           // location is now at payload length
		[data getBytes:&payloadLength range:r];
        r.location++;                           // location is now at payload
        r.length = payloadLength;
		// process data received from the accessory
        if (cmdReceived == CMD_ACK && payloadLength >= 1) {
#ifdef RPDEBUG
            NSString *cmdString = @"UNKNOWN";
#endif
            [data getBytes:buf range:r];
            switch(buf[0])  // Command being acked
            {
                case CMD_GET_TRIM:
                    if (payloadLength == 9) {
                        self.trimLeftPwm = (int16_t)(buf[1]<<8) + buf[2];
                        self.trimRightPwm = (int16_t)(buf[3]<<8) + buf[4];
                        self.trimLeftCurrent = (int16_t)(buf[5]<<8) + buf[6];
                        self.trimRightCurrent = (int16_t)(buf[7]<<8) + buf[8];
                        if ([_delegate respondsToSelector:@selector(dataReceivedForCommand:)]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [_delegate dataReceivedForCommand:CMD_GET_TRIM];
                            });
                        }
#ifdef RPDEBUG
                        cmdString = @"CMD_GET_TRIM";
#endif
                    }
                    break;
                case CMD_GET_VITALS:
                    if (payloadLength == 4) {
                        // Battery Status
                        self.batteryStatus = (uint16_t)(buf[1]<<8) + buf[2];
                        // Charging State
                        self.chargingState = buf[3];
                        // Motor Current
                        //self.motorCurrentLeft = (uint16_t)(buf[4]<<8) + buf[5];
                        //self.motorCurrentRight = (uint16_t)(buf[6]<<8) + buf[7];
                        //self.motorCurrentTilt = (uint16_t)(buf[8]<<8) + buf[9];
                        //_unackedHeartbeats = 0;
#ifdef RPDEBUG
                        cmdString = @"CMD_GET_VITALS";
#endif
                    }
                    break;
                case CMD_GET_MOTOR_CURRENT:
                    if (payloadLength == 7) {
                        self.motorCurrentLeft = (uint16_t)(buf[1]<<8) + buf[2];
                        self.motorCurrentRight = (uint16_t)(buf[3]<<8) + buf[4];
                        self.motorCurrentTilt = (uint16_t)(buf[5]<<8) + buf[6];
                        if ([_delegate respondsToSelector:@selector(dataReceivedForCommand:)]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [_delegate dataReceivedForCommand:CMD_GET_MOTOR_CURRENT];
                            });
                        }
#ifdef RPDEBUG
                        cmdString = @"CMD_GET_MOTOR_CURRENT";
#endif
                    }
                    break;
                case CMD_GET_BATTERY_STATUS:
                    if (payloadLength == 3) {
                        self.batteryStatus = (uint16_t)(buf[1]<<8) + buf[2];
                        if ([_delegate respondsToSelector:@selector(dataReceivedForCommand:)]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [_delegate dataReceivedForCommand:CMD_GET_BATTERY_STATUS];
                            });
                        }
#ifdef RPDEBUG
                        cmdString = @"CMD_GET_BATTERY_STATUS";
#endif
                    }
                    break;
                case CMD_GET_CHARGING_STATE:
                    if (payloadLength == 2) {
                        self.chargingState = buf[1];
                        if ([_delegate respondsToSelector:@selector(dataReceivedForCommand:)]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [_delegate dataReceivedForCommand:CMD_GET_CHARGING_STATE];
                            });
                        }
#ifdef RPDEBUG
                        cmdString = @"CMD_GET_CHARGING_STATE";
#endif
                    }
                    break;
                default: // Unknown command
#ifdef RPDEBUG
                    cmdString = [NSString stringWithFormat:@"0x%X",buf[0]];
#endif
                    break;
                    
            }
            
            // Reset response counter to note contact from robot
            dispatch_async(_commandQueue, ^{
                _ticksSinceLastResponse = 0;
            });
#ifdef RPDEBUG
            NSLog(@"Response received for command: %@",cmdString);
#endif
        }
        ret = r.location + r.length;
	}
	return ret;
}

@end
