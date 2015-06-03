//
//  RMCoreRobotIdentification.m
//  RMCore
//
//  Created on 2013-04-16.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMCoreRobotIdentification_Internal.h"
#import "RMCoreRobot_Internal.h"

@interface RMCoreRobotIdentification()

@property (nonatomic, weak)RMCoreRobotDataTransport *transport;

@end

@implementation RMCoreRobotIdentification

- (id)initWithTransport:(RMCoreRobotDataTransport *)transport
{
    _transport = transport;
    return self;
}

#pragma mark - Public readonly properties

- (NSString *)name
{
    return self.transport.name;
}

- (NSString *)modelNumber
{
    return self.transport.modelNumber;
}

- (NSString *)firmwareVersion
{
    return self.transport.firmwareVersion;
}

- (NSString *)hardwareVersion
{
    return self.transport.hardwareVersion ? self.transport.hardwareVersion : @"1.0.14";
}

- (NSString *)bootloaderVersion
{
    return self.transport.bootloaderVersion;
}

- (NSString *)serialNumber
{
    return self.transport.serialNumber;
}

- (NSString *)manufacturer
{
    return self.transport.manufacturer;
}

@end
