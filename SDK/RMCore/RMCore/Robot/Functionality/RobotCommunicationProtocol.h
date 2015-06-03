//
//  RobotCommunicationProtocol.h
//  RMCore
//
//  Created on 2013-04-06.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMCoreRobotDataTransport.h"
#import "RMCoreMotor.h"
#import "LEDModes.h"
#import "DeviceModes.h"
#import "ChargingStates.h"
#import "MotorCommandTypes.h"
#import "ParameterTypes.h"
#import "InfoTypes.h"
#import "SerialProtocol.h"

#define RMCoreRobotCommunicationVitalsUpdateNotification @"RMCoreRobotCommunicationVitalsUpdate"
#define RMCoreRobotCommunicationCurrentsUpdateNotification @"RMCoreRobotCommunicationCurrentsUpdate"

@protocol RMCoreRobotCommunicationDelegate;

@protocol RobotCommunicationProtocol <NSObject>

@property (nonatomic) RMDeviceMode deviceMode;
@property (nonatomic, readonly) RMChargingState chargingState;
@property (nonatomic, readonly) uint16_t batteryStatus;
@property (nonatomic, readonly, weak) RMCoreRobotDataTransport *transport;
@property (nonatomic, weak) id<RMCoreRobotCommunicationDelegate> delegate;
@property (nonatomic, readonly) BOOL supportsEvents;
@property (nonatomic, readonly) BOOL supportsLongBlinks;
@property (nonatomic, readonly) BOOL supportsMFIProgramming;
@property (nonatomic, readonly) BOOL supportsReset;

- (id)initWithTransport:(RMCoreRobotDataTransport *)transport;

@optional

- (uint16_t)requestMotorCurrent:(RMCoreMotorAxis)motor;
- (void)requestBatteryStatus;
- (void)requestChargingState;
- (void)requestVitals;
- (void)writeEEPROMAddress:(unsigned short int)address length:(unsigned char)length data:(NSData *)data;
- (void)readEEPROMAddress:(unsigned short int)address length:(unsigned char)length;
- (void)initialize;
- (void)setDeviceMode:(RMDeviceMode)deviceMode;
- (void)setMotorNumber:(RMCoreMotorAxis)motor commandType:(RMMotorCommandType)type value:(short int)value;
- (void)setLEDNumber:(unsigned char)led pwm:(unsigned char)pwm;
- (void)setLEDNumber:(unsigned char)led blinkOnTime:(unsigned short int)onTime blinkOffTime:(unsigned short int)offTime pwm:(unsigned char)pwm;
- (void)setLEDNumber:(unsigned char)led pulseTrigger:(unsigned char)trigger pulseCount:(unsigned char)count;
- (void)setLEDNumber:(unsigned char)led halfPulseUpTrigger:(unsigned char)trigger halfPulseUpCount:(unsigned char)count;
- (void)setLEDNumber:(unsigned char)led halfPulseDownTrigger:(unsigned char)trigger halfPulseDownCount:(unsigned char)count;
- (void)setLEDNumber:(unsigned char)led mode:(RMLedMode)mode;
- (void)requestParameter:(RMParameterType)parameter;
- (void)setParameter:(RMParameterType)parameter value:(unsigned char)value;
- (void)requestInfoType:(RMInfoType)type;
- (void)requestInfoType:(RMInfoType)type index:(unsigned char)index;
- (void)requestInfoType:(RMInfoType)type destination:(id)destination;
- (void)requestInfoType:(RMInfoType)type index:(unsigned char)index destination:(id)destination;
- (void)setInfoType:(RMInfoType)type index:(unsigned char)index value:(unsigned char)value;
- (void)setiDeviceChargeEnable:(BOOL)enable;
- (void)setiDeviceChargeCurrent:(unsigned short int)current;
- (void)enableWatchdog;
- (void)disableWatchdog;
- (void)softReset;
- (void)suspendCommunication;

@end

@protocol RMCoreRobotCommunicationDelegate <NSObject>
- (void)didReceiveAckForCommand:(RMCommandToRobot)command data:(NSData *)data;
- (void)didReceiveEvent:(RMAsyncEventType)event data:(NSData *)data;
@end

