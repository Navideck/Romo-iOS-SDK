/*
 * SerialProtocol.h
 * Romo3 Firmware
 *
 * Created by Aaron Solochek on 2013-03-10.
 * Copyright (c) 2013 Romotive. All rights reserved.
 */


#ifndef SERIALPROTOCOL_H
#define SERIALPROTOCOL_H

#define CMD_MAX_PAYLOAD                 160


/************************************************************************/
/* Commands to the robot Firmware >= 1.1.2                              */
/************************************************************************/
typedef enum {
    RMCommandToRobotSTX = 0x02,
    RMCommandToRobotETX = 0x03,
    
    RMCommandToRobotEnterBedOfNailsMode = 0x05,
    RMCommandToRobotEnterDanceMode = 0x07,
    RMCommandToRobotSTKOK = 0x10,
    RMCommandToRobotSTKFailed = 0x11,
    RMCommandToRobotSTKInSync = 0x14,
    RMCommandToRobotSTKNak = 0x15,

    RMCommandToRobotSetMode = 0x1A,
    RMCommandToRobotSTKCRCEOP = 0x20,
    RMCommandToRobotInitialize = 0x21,
    
    RMCommandToRobotSetMotor = 0x22,
//    RM_SER_CMD_SET_MOTORS_OLD = 0x23,
//    RM_SER_CMD_SET_MOTOR_LEFT = 0x24,
//    RM_SER_CMD_SET_MOTOR_RIGHT = 0x25,
//    RM_SER_CMD_SET_MOTOR_TILT = 0x26,
//    RM_SER_CMD_SET_MOTOR_REAR_LEFT = 0x27,
//    RM_SER_CMD_SET_MOTOR_REAR_RIGHT = 0x28,
    
    RMCommandToRobotSTKGetSync = 0x30,
    RMCommandToRobotGetVitals = 0x34,
    RMCommandToRobotGetMotorCurrent = 0x35,
    RMCommandToRobotGetBatteryStatus = 0x36,
    RMCommandToRobotGetChargingState = 0x37,
    RMCommandToRobotSetWatchdog = 0x38, //used
    
    RMCommandToRobotSetDeviceChargeEnable = 0x3A,
    RMCommandToRobotSetDeviceChargeCurrent = 0x3B,
    RMCommandToRobotGetFirmwareVersion = 0x3C,
    RMCommandToRobotGetHardwareVersion = 0x3D,
    RMCommandToRobotGetBootloaderVersion = 0x3E,
    
    
    RMCommandToRobotSetLeds = 0x40,
    RMCommandToRobotSTKGetParameter = 0x41,
    RMCommandToRobotSTKSetDevice = 0x42,
    RMCommandToRobotSetLedsPWM = 0x43,
    RMCommandToRobotSetLedsOff = 0x44,
    RMCommandToRobotSTKSetDeviceExt = 0x45,
    RMCommandToRobotSetLedsBlink = 0x46,
    RMCommandToRobotSetLedsPulse = 0x47,
    RMCommandToRobotSetLedsHalfPulseUp = 0x48,
    RMCommandToRobotSetLedsHalfPulseDown = 0x49,
    RMCommandToRobotSetLedsHeartbeat = 0x4A,
    RMCommandToRobotSetLedsBlinkLong = 0x4B,
    

    RMCommandToRobotSTKEnterProgrammingMode = 0x50,
    RMCommandToRobotSTKLeaveProgrammingMode = 0x51,
    RMCommandToRobotDisableWatchdog = 0x52,
    RMCommandToRobotSoftReset = 0x53,
    RMCommandToRobotSTKLoadAddress = 0x55,
    RMCommandToRobotSTKUniversal = 0x56,
    RMCommandToRobotReadEEPROM = 0x57,
    RMCommandToRobotWriteEEPROM = 0x58,
    
    RMCommandToRobotSTKProgramPage = 0x64,
    RMCommandToRobotSTKReadPage = 0x74,
    RMCommandToRobotSTKReadSignature = 0x75,
    
    
} RMCommandToRobot;


/************************************************************************/
/* Commands from the robot                                              */
/************************************************************************/
typedef enum {
    RMCommandFromRobotNak = 0x15,
    RMCommandFromRobotAsyncEvent = 0x20,
    RMCommandFromRobotAck = 0x40
} RMCommandFromRobot;


/************************************************************************/
/* Event types                                                          */
/************************************************************************/
typedef enum {
    RMAsyncEventTypeNull,
    RMAsyncEventTypeHeartbeat,
    RMAsyncEventTypeStartup
} RMAsyncEventType;




#endif // SERIALPROTOCOL_H