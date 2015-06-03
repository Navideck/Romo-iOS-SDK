//
//  RMCoreRobotCommunicationOld.h
//  RMCore
//

#import <Foundation/Foundation.h>
#import "RobotCommunicationProtocol.h"
#import "SerialProtocol.h"
#import "DeviceModes.h"
#import "ChargingStates.h"
#import "LEDModes.h"
#import "EEPROMDefs.h"
#import "Romo3Defs.h"


#define BATTERY_FULL                860     // 5.589V
#define BATTERY_EMPTY               685     // 4.3V

#define CMD_SET_LEDS                0x22
#define CMD_SET_MOTORS              0x23

#define CMD_READ_EEPROM             0x31
#define CMD_WRITE_EEPROM            0x32

#define CMD_GET_VITALS              0x34
#define CMD_GET_MOTOR_CURRENT       0x35
#define CMD_GET_BATTERY_STATUS      0x36
#define CMD_GET_CHARGING_STATE      0x37

#define CMD_SET_WATCHDOG            0x38
#define CMD_SET_LEDS_BLINK_LONG     0x39
#define CMD_SET_DEV_CHARGE_ENABLE   0x3A
#define CMD_SET_DEV_CHARGE_CURRENT  0x3B

#define CMD_ACK                     0x40

#define CMD_SET_LEDS_OFF            0x44
#define CMD_SET_LEDS_PWM            0x45    // deprecated
#define CMD_SET_LEDS_BLINK          0x46
#define CMD_SET_LEDS_PULSE          0x47
#define CMD_SET_LEDS_HALFPULSEUP    0x48
#define CMD_SET_LEDS_HALFPULSEDOWN  0x49

#define CMD_SET_MODE                0x50
#define CMD_DISABLE_WATCHDOG        0x52
#define CMD_SOFT_RESET              0x53

#define STK_LEAVE_PROGMODE          0x51


 
@interface RMCoreRobotCommunicationOld : NSObject <RobotCommunicationProtocol, RMCoreRobotDataTransportDelegate>

// Control values


// State values
@property (nonatomic, readonly) uint16_t motorCurrentLeft;
@property (nonatomic, readonly) uint16_t motorCurrentRight;
@property (nonatomic, readonly) uint16_t motorCurrentTilt;

@end
