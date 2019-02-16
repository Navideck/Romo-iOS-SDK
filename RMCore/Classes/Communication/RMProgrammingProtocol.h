//
//  RMProgrammingProtocol.h
//  RMCore
//
//  Created on 2013-05-04.
//  Copyright (c) 2013 Romotive. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "RMCoreRobotDataTransport.h"

#define RMCoreRobotProgrammerNotification @"ProgrammerNotification"

extern NSString *const RMCoreRobotDidConnectFirmwareUpdatingNotification;
extern NSString *const RMCoreRobotDidDisconnectFirmwareUpdatingNotification;
extern NSString *const RMCoreRobotDidConnectBrokenFirmwareNotification;
extern NSString *const RMCoreRobotDidDisconnectBrokenFirmwareNotification;
extern NSString *const RMCoreRobotDidFailToStartProgrammingNotification;

typedef enum {
    RMProgrammerStateInit,
    RMProgrammerStateSentStart,
    RMProgrammerStateProgramming,
    RMProgrammerStateVerifying,
    RMProgrammerStateDone,
    RMProgrammerStatePaused,
    RMProgrammerStateError,
    RMProgrammerStateAbort
} RMProgrammerState;

@protocol RMProgrammingProtocolDelegate;

@protocol RMProgrammingProtocol <NSObject>

@property (nonatomic, readonly) float programmerProgress;
@property (nonatomic, readonly) RMProgrammerState programmerState;
@property (nonatomic, weak) id<RMProgrammingProtocolDelegate> programmerDelegate;

- (id)initWithTransport:(RMCoreRobotDataTransport *)transport url:(NSString *)file;
- (void)programmerDataReceived:(NSData *)data;
- (void)programmerStart;
- (void)programmerAbort;

@end

