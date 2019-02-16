//
//  RMCoreRobot_Internal.h
//  RMCore
//
//  Created on 2013-04-11.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMCoreRobot.h"
#import "RobotCommunicationProtocol.h"
#import "RMCoreRobotDataTransport.h"

@interface RMCoreRobot ()

@property (nonatomic, strong) id<RobotCommunicationProtocol> communication;
@property (nonatomic, weak) RMCoreRobotDataTransport *transport;
@property (nonatomic, readonly) BOOL supportsFirmwareUpdating;
@property (nonatomic, readonly) BOOL supportsReset;
@property (nonatomic, getter = isSimulated) BOOL simulated;

- (id)initWithTransport:(RMCoreRobotDataTransport *)transport;
- (void)updateFirmware:(NSString *)fileURL;
- (void)stopUpdatingFirmware;
- (void)softReset;

@end
