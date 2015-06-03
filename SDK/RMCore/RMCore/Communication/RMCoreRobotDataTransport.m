//
//  RMCoreRobotConnection.m
//  RMCore
//

#import "RMCoreRobotDataTransport.h"
#import <libkern/OSAtomic.h>
#import "RMProgrammingProtocol.h"
#import "STK500Programmer.h"
#import <RMShared/RMMath.h>
#import "RMCoreRobotCommunicationOld.h"

#ifdef DEBUG_CONNECTION
#define CONNECT_LOG(...) DDLogWarn(__VA_ARGS__)
#else
#define CONNECT_LOG(...)
#endif //DEBUG_CONNECTION

#ifdef DEBUG_DATA_TRANSPORT
#define DT_LOG(...) DDLogWarn(__VA_ARGS__)
#else
#define DT_LOG(...)
#endif //DEBUG_DATA_TRANSPORT


NSString *const RMCoreRobotDidConnectFirmwareUpdatingNotification = @"RMCoreRobotDidConnectFirmwareUpdatingNotification";
NSString *const RMCoreRobotDidDisconnectFirmwareUpdatingNotification = @"RMCoreRobotDidDisconnectFirmwareUpdatingNotification";
NSString *const RMCoreRobotDidConnectBrokenFirmwareNotification = @"RMCoreRobotDidConnectBrokenFirmwareNotification";
NSString *const RMCoreRobotDidDisconnectBrokenFirmwareNotification = @"RMCoreRobotDidDisonnectBrokenFirmwareNotification";
NSString *const RMCoreRobotDidFailToStartProgrammingNotification = @"RMCoreRobotDidFailToStartProgrammingNotification";

static const float kVerifySendRate = 0.1; // 10Hz loop rate for verifying connection

@interface RMCoreRobotDataTransport ()

@property (nonatomic, readwrite, strong) EASession *session;
@property (nonatomic, strong) NSMutableData *txData;
@property (nonatomic, strong) NSMutableData *rxData;
@property (nonatomic) uint32_t isTransmittingBytes;

@property (nonatomic, strong) NSTimer *brokenFirmwareTimer;
@property (nonatomic, strong) NSTimer *robotVerificationTimer;

@property (nonatomic) uint8_t fwMaj;
@property (nonatomic) uint8_t fwMin;
@property (nonatomic) uint8_t fwRev;
@property (nonatomic) uint8_t hwMaj;
@property (nonatomic) uint8_t hwMin;
@property (nonatomic) uint8_t hwRev;
@property (nonatomic) uint8_t bootloaderMaj;
@property (nonatomic) uint8_t bootloaderMin;
@property (nonatomic) CFAbsoluteTime verificationStartTime;
@property (nonatomic, readwrite) BOOL MFIBootloader;
@property (nonatomic, readwrite) BOOL newMFIBootloader;
@property (nonatomic, readwrite) BOOL usesOldProtocol;
@property (nonatomic, readwrite) BOOL usesWatchdog;
@property (nonatomic, readwrite) BOOL isResettable;
@property (nonatomic, readwrite) BOOL isUpdatingFirmware;
@property (nonatomic, readwrite) BOOL corruptFirmware;
@property (nonatomic, strong) id<RMProgrammingProtocol> programmer;

@property (nonatomic) BOOL waitingForProgrammer;

@property (nonatomic, copy) void (^robotVerificationCompletion)(BOOL verified);
@property (nonatomic, copy) void (^transmitBytesCompletion)();
@property (nonatomic, copy) void (^closeSessionCompletion)(BOOL closed);

@property (nonatomic, getter=isShuttingDown) BOOL shuttingDown;
@property (nonatomic) BOOL hasTransmittedShutdownCommand;

@end

@implementation RMCoreRobotDataTransport

- (id)initWithDelegate:(id<RMCoreRobotConnectionDelegate>)delegate
{
    self = [super init];
    if (self) {
        DT_LOG(@"self: %@", self);
        _connectionDelegate = delegate;
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        
        _protocol = @"com.romotive.romo";
        [self accessoryDidConnect];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleExternalAccessoryDidConnectNotification:)
                                                     name:EAAccessoryDidConnectNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleExternalAccessoryDidDisconnectNotification:)
                                                     name:EAAccessoryDidDisconnectNotification
                                                   object:nil];
        
        [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}


- (void)dealloc
{
    DT_LOG(@"self: %@", self);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.robotVerificationTimer invalidate];
    [self.brokenFirmwareTimer invalidate];
    
    self.closeSessionCompletion = nil;
    [self closeSession];
}


#pragma mark - Connection Notifications


- (void)handleExternalAccessoryDidConnectNotification:(NSNotification *)notification
{
    CONNECT_LOG(@"");
    
    BOOL applicationIsInBackground = ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground);
    if (!applicationIsInBackground) {
        if (self.brokenFirmwareTimer.isValid) {
            [self.brokenFirmwareTimer invalidate];
        } else {
            if (self.softResetting) {
                [self closeSession];
            }
            
            if (!self.session) {
                [self accessoryDidConnect];
            }
        }
    }
}


- (void)handleExternalAccessoryDidDisconnectNotification:(NSNotification *)notification
{
    CONNECT_LOG(@"session: %@, softResetting: %d", self.session, self.isSoftResetting);

    if (self.session && !self.isSoftResetting) {
        if (self.robotVerificationTimer.isValid) {
            self.brokenFirmwareTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                        target:self
                                                                      selector:@selector(accessoryDidDisconnect)
                                                                      userInfo:nil
                                                                       repeats:NO];
        } else {
            [self accessoryDidDisconnect];
        }
    } else if (!self.session && (self.bootloaderMaj == 4) && (self.bootloaderMin == 5)){
        // hack to handle the bad state bootloader 4.5 sometimes gets into
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDidDisconnectFirmwareUpdatingNotification
                                                                object:self];
        });
    } else {
        [self accessoryDidDisconnect];
    }
}


- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self accessoryDidConnect];
}


- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    if (self.session) {
        self.shuttingDown = YES;
        [self accessoryDidDisconnect];
    }
}


#pragma mark - Connection Managing


- (void)accessoryDidConnect
{
    CONNECT_LOG(@"");
    [self.robotVerificationTimer invalidate];
    self.robotVerificationTimer = nil;
    
    [self openSession];
    
    if (self.session.accessory.isConnected) {
        if (!self.isUpdatingFirmware) {
            NSArray *hw = [self.hardwareRevision componentsSeparatedByString:@"."];
            if (hw.count == 3) {
                _hwMaj = [hw[0] intValue];
                _hwMin = [hw[1] intValue];
                _hwRev = [hw[2] intValue];
            }
            
            NSArray *fw = [self.firmwareRevision componentsSeparatedByString:@"."];
            if (fw.count == 3) {
                _fwMaj = [fw[0] intValue];
                _fwMin = [fw[1] intValue];
                _fwRev = [fw[2] intValue];
            }
            
            CONNECT_LOG(@"self: %@ hardware: %@, firmware: %@, bootloader: %d.%d",
                        self, self.hardwareRevision, self.firmwareRevision, self.bootloaderMaj, self.bootloaderMin);
            
            // This is what the bootloader will report the firmware major version as
            if(self.fwMaj == 0) {
                self.bootloaderMaj = self.fwMin;
                self.bootloaderMin = self.fwRev;
                self.MFIBootloader = YES;
                self.newMFIBootloader = YES;
            }
            // Anything with 1.1.* firmware almost certainly has an MFI bootloader
            else if((self.fwMaj > 1) || (self.fwMin >= 1)) {
                self.MFIBootloader = YES;
                self.newMFIBootloader = YES;
            }
            else {
                self.MFIBootloader = NO;
                self.newMFIBootloader = NO;
            }
            
            if (self.MFIBootloader) {
                [self exitBootloader];
                
                [self verifyRobotWithCompletion:^(BOOL verified) {
                    if (verified) {
                        self.corruptFirmware = NO;
                        [self firmwareVersionDidChange];

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.connectionDelegate robotDidConnect:self.name];
                        });
                    } else {
                        BOOL isCharging = [UIDevice currentDevice].batteryState == UIDeviceBatteryStateCharging ||
                        [UIDevice currentDevice].batteryState == UIDeviceBatteryStateFull;
                        if (!isCharging) {
                            self.corruptFirmware = YES;
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDidConnectBrokenFirmwareNotification
                                                                                    object:self];
                            });
                        }
                    }
                }];
                
            } else {
                self.corruptFirmware = NO;
                self.softResetting = NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.connectionDelegate robotDidConnect:self.name];
                });
            }
        } else {
            self.softResetting = NO;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDidConnectFirmwareUpdatingNotification
                                                                    object:self];
            });
            
            self.waitingForProgrammer = YES;
            [self.programmer programmerStart];
        }
    }
}


- (void)accessoryDidDisconnect
{
    CONNECT_LOG(@"");
    [self.brokenFirmwareTimer invalidate];
    [self.robotVerificationTimer invalidate];
    self.robotVerificationTimer = nil;
    self.robotVerificationCompletion = nil;
    
    if (self.disconnectCompletion) {
        BOOL disconnected = !self.session.accessory.isConnected || self.isUpdatingFirmware;
        self.disconnectCompletion(self, disconnected);
        self.disconnectCompletion = nil;
    }
    

    if (self.session.outputStream.hasSpaceAvailable) {
        @synchronized(self) {
            [self transmitShutdownCommand];
        }
    }

    [self closeSession];
    
    self.hwMaj = self.hwMin = self.hwRev = 0;
    self.fwMaj = self.fwMin = self.fwRev = 0;
    self.bootloaderMaj = self.bootloaderMin = 0;
    
    if (self.isUpdatingFirmware) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDidDisconnectFirmwareUpdatingNotification
                                                                object:self];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.corruptFirmware) {
                [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDidDisconnectBrokenFirmwareNotification
                                                                    object:self];
            } else {
                [self.connectionDelegate robotDidDisconnect:self];
            }
            
        });
    }
}


- (void)verifyRobotWithCompletion:(void (^)(BOOL verified))completion
{
    self.robotVerificationCompletion = completion;
    self.verificationStartTime = 0;
    self.robotVerificationTimer = [NSTimer scheduledTimerWithTimeInterval:kVerifySendRate
                                                                   target:self
                                                                 selector:@selector(verifyRobot)
                                                                 userInfo:nil
                                                                  repeats:YES];
}


- (void)verifyRobot
{
    if (!self.verificationStartTime) {
        self.verificationStartTime = currentTime();
    }
    
    BOOL timedOut = currentTime() - self.verificationStartTime > 2.5;
    BOOL verified = (self.fwMaj != 0) && (self.bootloaderMaj != 0) && (self.hwMaj != 0);
    
    if (timedOut || verified) {
        [self.robotVerificationTimer invalidate];
        self.robotVerificationTimer = nil;
        
        self.softResetting = NO;
        
        if (self.robotVerificationCompletion) {
            self.robotVerificationCompletion(verified);
            self.robotVerificationCompletion = nil;
        }
    } else if (self.hwMaj == 0){
        [self requestHardwareVersion];
    } else if (self.fwMaj == 0) {
        [self requestFirmwareVersion];
    } else if (self.bootloaderMaj == 0) {
        [self requestBootloaderVersion];
    }
}


#pragma mark - Data Session Methods


- (void)openSession
{
    CONNECT_LOG(@"self: %@", self);
    self.shuttingDown = NO;
    self.hasTransmittedShutdownCommand = NO;

    __block void (^openSession)(BOOL closed) = ^(BOOL closed){
        EAAccessory *accessory = [self romoAccessory];
        if (accessory) {
            // Older bootloaders expect to see an ACK to RequestApplicationLaunch before they see OpenDataSessionForProtocol
            // This sleep guarantees that is the case.
            if(!self.newMFIBootloader) {
                usleep(50000);
            }
            
            self.session = [[EASession alloc] initWithAccessory:accessory forProtocol:self.protocol];
            
            if (self.session) {
                self.session.inputStream.delegate = self;
                [self performSelector:@selector(scheduleInCurrentThread:)
                             onThread:self.class.driverThread
                           withObject:self.session.inputStream
                        waitUntilDone:YES];
                [self.session.inputStream open];
                
                self.session.outputStream.delegate = self;
                [self performSelector:@selector(scheduleInCurrentThread:)
                             onThread:self.class.driverThread
                           withObject:self.session.outputStream
                        waitUntilDone:YES];
                [self.session.outputStream open];
            } else {
                // You forgot to put com.romotive.romo in your Info.plist!
                NSString *errorTitle = @"RMCore Error";
                NSString *errorMessage = @"If you're consistently seeing this, you must specify \"com.romotive.romo\" \
                in your project's Info.plist under \"Supported external accessory protocols\"";
                NSLog(@"%@: %@", errorTitle, errorMessage);
            }
        }
    };
    
    if (self.session) {
        self.closeSessionCompletion = openSession;
    } else {
        openSession(YES);
    }
}


- (void)closeSession
{
    CONNECT_LOG(@"");
    __block void (^closeSession)() = ^{
        CONNECT_LOG(@"");
        
        [self.session.inputStream close];
        [self performSelector:@selector(removeFromCurrentThread:)
                     onThread:self.class.driverThread
                   withObject:self.session.inputStream
                waitUntilDone:YES];
        
        self.session.inputStream.delegate = nil;

        [self.session.outputStream close];
        [self performSelector:@selector(removeFromCurrentThread:)
                     onThread:self.class.driverThread
                   withObject:self.session.outputStream
                waitUntilDone:YES];
        

        self.session.outputStream.delegate = nil;
        self.session = nil;
    
        if (self.closeSessionCompletion) {
            self.closeSessionCompletion(YES);
            self.closeSessionCompletion = nil;
        }
    };
    
    if (self.txData.length) {
        self.transmitBytesCompletion = closeSession;
    } else {
        closeSession();
    }
}


#pragma mark - Stream delegate methods


- (void)stream:(NSStream*)stream handleEvent:(NSStreamEvent)streamEvent
{
    switch (streamEvent) {
        case NSStreamEventHasBytesAvailable: {
            int bytesRead = 0;
            uint8_t buffer[20];
            
            // Get bytes from the stream and put them into buf for processing
            while((bytesRead = [(NSInputStream *)stream read:buffer maxLength:sizeof(buffer)])) {
                [self.rxData appendBytes:buffer length:bytesRead];
            }
            
            // Process received data
            // Minimum data packet for local purposes is 2 bytes
            NSRange r = NSMakeRange(0, 2);
            while (r.location + 2 < self.rxData.length) {
                r.length = self.rxData.length - r.location; // try to read everything left
                int bytesRead = [self readData:[self.rxData subdataWithRange:r]];
                r.location += bytesRead; // move the start of the subdata to the next command
            }
            
            if (r.location >= self.rxData.length) {
                // If all data has been processed, release the receiver
                self.rxData = nil;
            } else {
                // Otherwise reset it with the remaining bytes
                r.length = self.rxData.length - r.location;
                self.rxData.data = [self.rxData subdataWithRange:r];
            }
            break;
        }
            
        case NSStreamEventHasSpaceAvailable:
            // Send any queued commands
            @synchronized(self) {
                [self transmitBytes];
            }
            break;
            
        default:
            break;
    }
}


#pragma mark - Stream handling functions


- (void)queueTxBytes:(NSData *)bytes
{
    if (bytes.length && self.session.accessory.isConnected && !self.isShuttingDown) {
        [self.txData appendData:bytes];
        
        if (self.session.outputStream.hasSpaceAvailable) {
            @synchronized(self) {
                [self transmitBytes];
            }
        }
    }
}


- (void)clearTxBytes
{
    self.txData = nil;
}


- (void)transmitBytes
{
    if (self.isShuttingDown) {
        // Don't transmit anything while shutting down
        return;
    }

    if (self.txData.length) {
        int bytesSent = [self.session.outputStream write:self.txData.bytes maxLength:self.txData.length];
        
        if (bytesSent < self.txData.length && bytesSent >= 0) {
            NSRange unsentRange = NSMakeRange(bytesSent, self.txData.length - bytesSent);
            self.txData.data = [self.txData subdataWithRange:unsentRange];
        } else {
            self.txData = nil;
        }
    }
    
    if (!self.txData.length && self.transmitBytesCompletion) {
        self.transmitBytesCompletion();
        self.transmitBytesCompletion = nil;
    }
}

- (void)transmitShutdownCommand
{
    if (self.isShuttingDown && !self.hasTransmittedShutdownCommand) {
        self.hasTransmittedShutdownCommand = YES;

        [self clearTxBytes];

        // Immediately write a buffer that says to stop driving
        uint8_t shutdownBytes[] = { CMD_SET_MOTORS, 6, 0, 0, 0, 0, 0, 0, CMD_DISABLE_WATCHDOG, 0, CMD_SET_LEDS_OFF, 0 };
        NSData *data = [NSData dataWithBytes:shutdownBytes length:sizeof(shutdownBytes)];
        [self.session.outputStream write:data.bytes maxLength:data.length];
    }
}

#pragma mark - Transport


- (void)updateFirmware:(NSString *)fileURL
{
#ifdef DEBUG_FIRMWARE_UPDATING
    DDLogWarn(@"");
#endif
    if (!self.isSoftResetting && !self.waitingForProgrammer) {
        self.isUpdatingFirmware = YES;
        
        if (self.isResettable) {
            [self.connectionDelegate robotDidDisconnect:self];
            [self clearTxBytes];
        }
            
        // If we can reset the robot, do so
        // If the firmware is corrupt, sending a softReset should cause it to crash and reboot
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.programmer = [[STK500Programmer alloc] initWithTransport:self url:fileURL];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.isResettable || self.corruptFirmware) {
                    [self softReset];
                }
            });
        });
    }
}


- (void)stopUpdatingFirmware
{
#ifdef DEBUG_FIRMWARE_UPDATING
    DDLogWarn(@"");
#endif
    
    if(self.isUpdatingFirmware) {
        self.programmer = nil;
        self.isUpdatingFirmware = NO;
        
        __block void (^softReset)() = ^{
            if (self.session) {
                [self exitBootloader];
                
                
                if(self.newMFIBootloader) {
                    self.fwMaj = self.fwMin = self.fwRev = 0;
                    [self verifyRobotWithCompletion:^(BOOL verified) {
                        if (verified) {
                            self.corruptFirmware = NO;
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
#ifdef DEBUG_FIRMWARE_UPDATING
                                DDLogWarn(@"robot verified: %@", self.name);
#endif
                                [self.connectionDelegate robotDidConnect:self.name];
                            });
                        } }];
                }
                else {
                    self.isResettable = YES;
                    [self softReset];
                }
            }
        };
        
        if(self.session) {
            if(self.txData.length) {
                self.transmitBytesCompletion = softReset;
            } else {
                softReset();
            }
        }
    }
}


// read the first complete command out of the data buffer and deal with it
// return the number of bytes read from that packet, or 0 on error
- (int)readData:(NSData *)data
{
    // Raw data buffer coming in
    if (data.length >= 2) {
        int read = 0;
        NSRange r = NSMakeRange(0, 1);
        
        uint8_t packetType = 0;
        uint8_t payloadLength = 0;
        uint8_t packetCommand = 0;
        uint8_t buffer[CMD_MAX_PAYLOAD];
        
        // read the packet type byte (index 0)
        r.location = 0;
        [data getBytes:&packetType range:r];
        
        // move to payload length byte (index 1)
        r.location++;
        [data getBytes:&payloadLength range:r];
        
        read = 2;
        
        if (payloadLength && data.length >= 2 + payloadLength) {
            // move to payload bytes (index 2)
            r.location++;
            [data getBytes:&packetCommand range:r];
            
            // payload includes the command, which we are stripping off
            payloadLength--;
            
            // move to response data bytes (index 3+)
            r.location++;
            r.length = payloadLength;
            
            read = 3 + payloadLength;
        }
        
        switch(packetType) {
                // handle ACKs to commands we sent to the robot
                // special cases here are versions, which get set right away, and firmware programming command ACKs,
                // which get handled by a specific delegate.
            case RMCommandFromRobotAck:
                
                [data getBytes:buffer range:r];
                switch (packetCommand) {  // Received Command
                    case RMCommandToRobotGetHardwareVersion:
                        if (payloadLength == 3) {
                            self.hwMaj = buffer[0];
                            self.hwMin = buffer[1];
                            self.hwRev = buffer[2];
                        }
                        break;
                        
                    case RMCommandToRobotGetFirmwareVersion:
                        if (payloadLength == 3) {
                            self.fwMaj = buffer[0];
                            self.fwMin = buffer[1];
                            self.fwRev = buffer[2];
                            [self firmwareVersionDidChange];
                        }
                        break;
                        
                    case RMCommandToRobotGetBootloaderVersion:
                        if (payloadLength == 2) {
                            self.bootloaderMaj = buffer[0];
                            self.bootloaderMin = buffer[1];
                            [self firmwareVersionDidChange];
                        }
                        break;
                        
                    case RMCommandToRobotSoftReset:
                        break;
                        
                    case RMCommandToRobotSTKInSync: {
                        self.waitingForProgrammer = NO;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.programmer programmerDataReceived:[NSData dataWithData:[data subdataWithRange:r]]];
                        });
                        break;
                    }
                        
                    default: // Pass the acked command up to the delegate
                        if ([self.transportDelegate respondsToSelector:@selector(didReceiveAckForCommand:data:)]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.transportDelegate didReceiveAckForCommand:(RMCommandToRobot)packetCommand
                                                                           data:[data subdataWithRange:r]];
                            });
                        }
                        break;
                        
                }
                break;
                
                // Handle asynchronous events from the robot
            case RMCommandFromRobotAsyncEvent:
                [data getBytes:buffer range:r];
                switch(packetCommand) {
                    case RMAsyncEventTypeStartup:
                        break;
                        
                    default:
                        if ([self.transportDelegate respondsToSelector:@selector(didReceiveEvent:data:)]) {
                            [self.transportDelegate didReceiveEvent:(RMAsyncEventType)packetCommand
                                                               data:[data subdataWithRange:r]];
                        }
                }
                
                break;
                
            case RMCommandFromRobotNak:
                switch (packetCommand) {
                    case RMCommandToRobotSTKReadSignature:
                        if (self.waitingForProgrammer) {
                            [self verifyRobotWithCompletion:^(BOOL verified) {
                                if (verified && self.isResettable) {
                                    [self softReset];
                                } else {
                                    [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDidFailToStartProgrammingNotification
                                                                                        object:self];
                                }
                            }];
                        }
                        break;
                        
                    default:
                        break;
                }
                break;
        }
        return read;
    }
    return 0;
}


- (BOOL)isAccessoryConnected
{
    return self.session.accessory.isConnected;
}


- (NSString *)firmwareVersion
{
    return [NSString stringWithFormat:@"%d.%d.%d", self.fwMaj, self.fwMin, self.fwRev];
}


- (NSString *)hardwareVersion
{
    return [NSString stringWithFormat:@"%d.%d.%d", self.hwMaj, self.hwMin, self.hwRev];
}


- (NSString *)bootloaderVersion
{
    return [NSString stringWithFormat:@"%d.%d", self.bootloaderMaj, self.bootloaderMin];
}


- (void)requestBootloaderVersion
{
    uint8_t cmd[2] = {RMCommandToRobotGetBootloaderVersion, 0};
    [self queueTxBytes:[NSData dataWithBytes:&cmd length:2]];
}


- (void)requestFirmwareVersion
{
    uint8_t cmd[2] = {RMCommandToRobotGetFirmwareVersion, 0};
    [self queueTxBytes:[NSData dataWithBytes:&cmd length:2]];
}


- (void)requestHardwareVersion
{
    uint8_t cmd[2] = {RMCommandToRobotGetHardwareVersion, 0};
    [self queueTxBytes:[NSData dataWithBytes:&cmd length:2]];
}


- (void)exitBootloader
{
    uint8_t cmd[2] = {RMCommandToRobotSTKLeaveProgrammingMode, 0};
    [self queueTxBytes:[NSData dataWithBytes:&cmd length:2]];
}


- (void)softReset
{
    if (!self.isSoftResetting && self.isResettable && self.session) {
        self.softResetting = YES;
        
        self.transmitBytesCompletion = nil;
        self.disconnectCompletion = nil;
        
        uint8_t softResetCommand[2] = {RMCommandToRobotSoftReset, 0};
        [self clearTxBytes];
        [self queueTxBytes:[NSData dataWithBytes:&softResetCommand length:2]];
    }
}


- (void)setWatchdogNValueForRate:(float)minRate
{
    // Rate ~= 16 * 2^n milliseconds for n=[0,9]
    uint8_t n = 0;
    while((0.016f*pow(2,n)) <= minRate) {
        if (++n >= 9) {
            n = 9;
            break;
        }
    }
    [self setWatchdog:n];
}


- (void)disableWatchdog
{
    if (self.usesWatchdog) {
        uint8_t cmd[2] = {RMCommandToRobotDisableWatchdog, 0};
        [self queueTxBytes:[[NSData alloc] initWithBytes:&cmd length:2]];
    }
}


- (void)setWatchdog:(RMRobotWatchdogTimeout)val
{
    if (self.usesWatchdog) {
        uint8_t cmd[3] = {RMCommandToRobotSetWatchdog, 1, val};
        [self queueTxBytes:[[NSData alloc] initWithBytes:&cmd length:3]];
    }
}


- (void)firmwareVersionDidChange
{
    self.MFIBootloader = (self.bootloaderMaj >= 4);
    self.newMFIBootloader = (self.bootloaderMaj > 4) || (self.bootloaderMin > 5);
    self.usesOldProtocol = ((self.fwMaj < 1) || ((self.fwMaj == 1) && (self.fwMin < 2)));
    self.usesWatchdog = ((self.bootloaderMaj > 4) || (self.bootloaderMin >= 10));
    self.isResettable = ((self.fwMaj >= 1) && (self.fwMin >= 1) && (self.fwRev >= 2) &&
                         !((self.fwMaj == 1) && (self.fwMin == 1) && (self.fwRev == 8)));
}


#pragma mark - Thread Handling


+ (NSThread *)driverThread {
    static NSThread *driverThread = nil;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        driverThread = [[NSThread alloc] initWithTarget:self
                                               selector:@selector(driverThreadMain:)
                                                 object:nil];
        driverThread.name = @"com.Romotive.RMCoreRobotDataTransport";
        [driverThread start];
    });
    
    return driverThread;
}


+ (void)driverThreadMain:(id)unused {
    do {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] run];
        }
    } while (YES);
}


- (void)scheduleInCurrentThread:(NSStream *)stream
{
    [stream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                      forMode:NSRunLoopCommonModes];
}


- (void)removeFromCurrentThread:(NSStream *)stream
{
    [stream removeFromRunLoop:[NSRunLoop currentRunLoop]
                      forMode:NSRunLoopCommonModes];
}


#pragma mark - Private Properties


- (EAAccessory *)romoAccessory
{
    NSArray *accessories = [EAAccessoryManager sharedAccessoryManager].connectedAccessories;
    for (EAAccessory *accessory in accessories) {
        if ([accessory.protocolStrings containsObject:self.protocol]) {
            return accessory;
        }
    }
    return nil;
}


- (NSMutableData *)txData
{
    if (!_txData) {
        _txData = [NSMutableData data];
    }
    return _txData;
}


- (NSMutableData *)rxData
{
    if (!_rxData) {
        _rxData = [NSMutableData data];
    }
    return _rxData;
}


#pragma mark - External Accessory Identification Tokens


- (NSString *)name {return self.session.accessory.name;}
- (NSString *)manufacturer {return self.session.accessory.manufacturer;}
- (NSString *)modelNumber {return self.session.accessory.modelNumber;}
- (NSString *)serialNumber {return self.session.accessory.serialNumber;}
- (NSString *)firmwareRevision {return self.session.accessory.firmwareRevision;}
- (NSString *)hardwareRevision {return self.session.accessory.hardwareRevision;}

@end
