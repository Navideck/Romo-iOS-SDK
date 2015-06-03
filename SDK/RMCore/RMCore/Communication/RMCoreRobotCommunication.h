//
//  RMCoreRobotCommunication.h
//  RMCore
//

#import <Foundation/Foundation.h>
#import "RobotCommunicationProtocol.h"
#import "FirmwareCommon/SerialProtocol.h"
#import "FirmwareCommon/DeviceModes.h"
#import "FirmwareCommon/ChargingStates.h"
#import "FirmwareCommon/LEDModes.h"

#define BATTERY_FULL                860     // 5.589V
#define BATTERY_EMPTY               685     // 4.3V



@interface RMCoreRobotCommunication : NSObject <RobotCommunicationProtocol, RMCoreRobotDataTransportDelegate>

@property (nonatomic) RMDeviceMode deviceMode;

@property (nonatomic, readonly, getter=isConnected) BOOL connected;


// Firmware capabilities
@property (nonatomic, readonly) BOOL supportsLongBlinks;
@property (nonatomic, readonly) BOOL supportsMFIProgramming;

@end

