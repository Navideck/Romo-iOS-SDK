//
//  RMCoreRobotConnection.h
//  RMCore
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>
#import "SerialProtocol.h"

@protocol RMCoreRobotConnectionDelegate;
@protocol RMCoreRobotDataTransportDelegate;


typedef enum {
    RMRobotWatchdogTimeout15ms,
    RMRobotWatchdogTimeout30ms,
    RMRobotWatchdogTimeout60ms,
    RMRobotWatchdogTimeout120ms,
    RMRobotWatchdogTimeout250ms,
    RMRobotWatchdogTimeout500ms,
    RMRobotWatchdogTimeout1s,
    RMRobotWatchdogTimeout2s,
    RMRobotWatchdogTimeout4s,
    RMRobotWatchdogTimeout8s
} RMRobotWatchdogTimeout;


@interface RMCoreRobotDataTransport : NSObject <NSStreamDelegate>

@property (nonatomic, readonly) EASession *session;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *manufacturer;
@property (nonatomic, readonly) NSString *modelNumber;
@property (nonatomic, readonly) NSString *serialNumber;
@property (nonatomic, readonly) NSString *hardwareRevision;
@property (nonatomic, readonly) NSString *firmwareRevision;
@property (nonatomic, readonly) NSString *protocol;

@property (nonatomic, weak) id<RMCoreRobotConnectionDelegate> connectionDelegate;
@property (nonatomic, weak) id<RMCoreRobotDataTransportDelegate> transportDelegate;
@property (nonatomic, readonly) BOOL MFIBootloader;
@property (nonatomic, readonly) BOOL newMFIBootloader;
@property (nonatomic, readonly) BOOL usesOldProtocol;
@property (nonatomic, readonly) BOOL isAccessoryConnected;
@property (nonatomic, readonly) BOOL isUpdatingFirmware;
@property (nonatomic, readonly) BOOL usesWatchdog;
@property (nonatomic, readonly) BOOL isResettable;
@property (nonatomic, readonly) BOOL corruptFirmware;
@property (nonatomic, getter=isSoftResetting) BOOL softResetting;
@property (nonatomic, readonly) NSString *firmwareVersion;
@property (nonatomic, readonly) NSString *hardwareVersion;
@property (nonatomic, readonly) NSString *bootloaderVersion;

/**
 Called when the transport will be closing the session
 e.g. Disconnect from robot or backgrounding
 @param disconnected says whether or not the accessory is already disconnected
 */
@property (nonatomic, copy) void (^disconnectCompletion)(RMCoreRobotDataTransport *transport, BOOL disconnected);

- (id)initWithDelegate:(id <RMCoreRobotConnectionDelegate>)delegate;
- (void)queueTxBytes:(NSData *)buf;
- (void)clearTxBytes;
- (void)updateFirmware:(NSString *)file;
- (void)stopUpdatingFirmware;
- (void)exitBootloader;
- (void)softReset;
- (void)setWatchdogNValueForRate:(float)minRate;
- (void)setWatchdog:(RMRobotWatchdogTimeout)val;
- (void)disableWatchdog;

@end


@protocol RMCoreRobotConnectionDelegate <NSObject>

- (void)robotDidConnect:(NSString *)name;
- (void)robotDidDisconnect:(RMCoreRobotDataTransport *)transport;

@end

@protocol RMCoreRobotDataTransportDelegate <NSObject>

- (void)didReceiveAckForCommand:(RMCommandToRobot)command data:(NSData *)data;
- (void)didReceiveEvent:(RMAsyncEventType)event data:(NSData *)data;

@end

