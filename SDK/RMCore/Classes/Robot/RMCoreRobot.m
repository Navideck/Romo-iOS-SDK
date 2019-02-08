//
//  RMCoreRobot.m
//  RMCore
//

#import <UIKit/UIKit.h>
#import "RMCoreRobot.h"
#import "RMCoreRobot_Internal.h"
#import "RMCoreRobotIdentification_Internal.h"

NSString *const RMCoreRobotDriveSpeedDidChangeNotification = @"RMCoreRobotDriveSpeedDidChangeNotification";
NSString *const RMCoreRobotHeadTiltSpeedDidChangeNotification = @"RMCoreRobotTiltgitSpeedDidChangeNotification";

@implementation RMCoreRobot

- (id)initWithTransport:(RMCoreRobotDataTransport *)transport
{
    if (self = [super init]) {
        _transport = transport;
        _identification = [[RMCoreRobotIdentification alloc] initWithTransport:transport];
    }
    return self;
}

- (BOOL)isDrivable
{
    return [self conformsToProtocol:@protocol(DriveProtocol)];
}

- (BOOL)isHeadTiltable
{
    return [self conformsToProtocol:@protocol(HeadTiltProtocol)];
}

- (BOOL)isLEDEquipped
{
    return [self conformsToProtocol:@protocol(LEDProtocol)];
}

- (BOOL)isIMUEquipped
{
    return [self conformsToProtocol:@protocol(RobotMotionProtocol)];
}

- (BOOL)isConnected
{
    return self.communication.transport.session != nil;
}

- (float)powerLevel
{
    return 0.0;
}

- (void)stopAllMotion
{
    return;
}

- (BOOL)supportsFirmwareUpdating
{
    return self.transport.MFIBootloader;
}

- (BOOL)supportsReset
{
    return self.transport.isResettable;
}

- (void)updateFirmware:(NSString *)fileURL
{
    [self.communication suspendCommunication];
    [self.transport updateFirmware:fileURL];
}

- (void)stopUpdatingFirmware
{
    [self.transport stopUpdatingFirmware];
}

- (void)softReset
{
    [self.communication softReset];
}

@end
