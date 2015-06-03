//
//  MFIDriver.h
//  RomoTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>


@interface MFIDriver : NSObject <EAAccessoryDelegate, NSStreamDelegate>
{
	NSString *theProtocol;
    EASession *eas;
    BOOL streamReady;
    NSMutableData *txData;
    NSMutableData __strong *rxData;
}

- (int)readData:(NSData *) data;
- (id)initWithProtocol:(NSString *)protocol;
- (bool)isConnected;
- (void)accessoryDidConnect:(NSNotification *)notification;
- (void)accessoryDidDisconnect:(NSNotification *)notification;
- (NSString *)name;
- (NSString *)manufacturer;
- (NSString *)modelNumber;
- (NSString *)serialNumber;
- (NSString *)firmwareRevision;
- (NSString *)hardwareRevision;
- (EASession *)openSessionForProtocol:(NSString *)protocolString;
- (void)queueTxBytes:(NSData *)buf;
- (void)transmitBytes;

@end
