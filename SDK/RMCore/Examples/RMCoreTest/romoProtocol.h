//
//  RomoProtocol.h
//  RomoTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MFIDriver.h"

#define BATTERY_FULL                752     // 5V
#define BATTERY_EMPTY               662     // 4.4V
#define CMD_MAX_PAYLOAD             130

#define CMD_INITIALIZE              0x21
#define CMD_SET_LEDS                0x22
#define CMD_SET_MOTORS              0x23
#define CMD_SET_MOTOR_LEFT          0x24
#define CMD_SET_MOTOR_RIGHT         0x25
#define CMD_SET_MOTOR_TILT          0x26

#define CMD_SET_TRIM_PWM            0x30
#define CMD_SET_TRIM_CURRENT        0x31
#define CMD_GET_TRIM                0x32
#define CMD_SET_TRIM_FLAG           0x33

#define CMD_GET_VITALS              0x34
#define CMD_GET_MOTOR_CURRENT       0x35
#define CMD_GET_BATTERY_STATUS      0x36
#define CMD_GET_CHARGING_STATE      0x37

#define CMD_ACK                     0x40
#define CMD_READ_EEPROM             0x41
#define CMD_WRITE_EEPROM            0x42

#define CMD_SET_LEDS_OFF            0x44
#define CMD_SET_LEDS_PWM            0x45
#define CMD_SET_LEDS_BLINK          0x46
#define CMD_SET_LEDS_PULSE          0x47
#define CMD_SET_LEDS_HALFPULSEUP    0x48
#define CMD_SET_LEDS_HALFPULSEDOWN  0x49

#define CMD_SET_MODE                0x50
#define CMD_SET_WATCHDOG            0x51
#define CMD_DISABLE_WATCHDOG        0x52
#define CMD_SOFT_RESET              0x53

typedef enum {
	LED_MODE_OFF,
	LED_MODE_NORMAL,
	LED_MODE_BLINK,
	LED_MODE_PULSE,
    LED_MODE_HALFPULSEUP,
    LED_MODE_HALFPULSEDOWN
} LED_MODE;

typedef enum chargingState_t {
    CHARGING_STATE_OFF,
    CHARGING_STATE_ON,
    CHARGING_STATE_ERROR,
    CHARGING_STATE_UNKNOWN
} CHG_STATE;

typedef enum {
    DEV_MODE_UNKNOWN,
    DEV_MODE_RUN,
    DEV_MODE_DEBUG,
    DEV_MODE_DANCE,
    DEV_MODE_CHARGE
} DEV_MODE;

@class RomoProtocol;

@protocol RomoDelegate <NSObject>

- (void)didConnectToRobot;
- (void)didDisconnectFromRobot;
- (void)lostContactWithRobot;
- (void)dataReceivedForCommand:(uint8_t)command;

@end

@interface RomoProtocol : MFIDriver

@property (weak, nonatomic) id<RomoDelegate>delegate;
@property (nonatomic) DEV_MODE deviceMode;

// Control values
@property (nonatomic) LED_MODE ledMode;
@property (nonatomic) uint8_t ledPwm;
@property (nonatomic) uint16_t ledBlinkOnDelay;
@property (nonatomic) uint16_t ledBlinkOffDelay;
@property (nonatomic) uint8_t ledPulseCnt;
@property (nonatomic) uint8_t ledPulseStep;
@property (nonatomic) int16_t motorValueLeft;
@property (nonatomic) int16_t motorValueRight;
@property (nonatomic) int16_t motorValueTilt;

// Trim values
@property (nonatomic) bool trimEnabledOnRobot;
@property (nonatomic) int16_t trimLeftPwm;
@property (nonatomic) int16_t trimRightPwm;
@property (nonatomic) int16_t trimLeftCurrent;
@property (nonatomic) int16_t trimRightCurrent;

// State values
@property (nonatomic,readonly) uint16_t motorCurrentLeft;
@property (nonatomic,readonly) uint16_t motorCurrentRight;
@property (nonatomic,readonly) uint16_t motorCurrentTilt;
@property (nonatomic,readonly) uint16_t batteryStatus;
@property (nonatomic,readonly) uint8_t batteryPercentage;
@property (nonatomic,readonly) CHG_STATE chargingState;

+ (RomoProtocol *)shared;
- (void)sendTrimPwmValues;
- (void)sendTrimCurrentValues;
- (void)requestTrim;
- (void)requestMotorCurrent;
- (void)requestBatteryStatus;
- (void)requestChargingState;
// readEeprom
// writeEeprom
- (void)setWatchdogNValueForRate:(float)minRate;
- (void)enableWatchdogOnRobot;
- (void)disableWatchdogOnRobot;
- (void)sendSoftReset;
- (void)goToSleep;
- (void)wakeUp;

@end
