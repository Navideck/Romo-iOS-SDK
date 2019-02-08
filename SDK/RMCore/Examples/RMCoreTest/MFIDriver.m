//
//  MFIDriver.m
//  RomoTest
//
//  Created by Dan Kane on 6/26/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//

#import "MFIDriver.h"

@interface MFIDriver ()
{
    dispatch_queue_t _receiveQueue;
}
@end

@implementation MFIDriver

// To be overloaded by protocol subclass
- (int)readData:(NSData *) data
{
	return [data length];
}

- (id)initWithProtocol:(NSString *)protocol
{
	theProtocol = protocol;
	// Try to open a session with the given protocol
	eas = [self openSessionForProtocol:theProtocol];
    if(eas == nil)
    {
        // No valid accessory found
    }
    
	// Set up notifications for accessory connect and disconnect
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(accessoryDidConnect:)
												 name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(accessoryDidDisconnect:)
                                                 name:EAAccessoryDidDisconnectNotification object:nil];
    
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
    
    _receiveQueue = dispatch_queue_create("com.romotive.receiveQueue", NULL);

    return self;
}

- (bool)isConnected
{
	return [eas.accessory isConnected];
}


#pragma mark - Accessory Notifications

- (void)accessoryDidConnect:(NSNotification *)notification
{
    NSLog(@"Accessory Connected");
    eas = [self openSessionForProtocol:theProtocol];
    // Make sure it worked, if desired
    //if(eas != nil)
    //{
    //}
}

- (void)accessoryDidDisconnect:(NSNotification *)notification
{
    NSLog(@"Accessory Disconnected");
    [[eas inputStream] close];
    [[eas outputStream] close];
    eas = nil;
}


#pragma mark - Data Session Methods

- (EASession *)openSessionForProtocol:(NSString *)protocolString 
{
    // Get list of accessories
    NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager]
                            connectedAccessories];
	
    EAAccessory *accessory = nil;
    EASession *session = nil;
    
    // Query accessories for supported protocol string
	for (EAAccessory *acc in accessories)
    {
        if ([[acc protocolStrings] containsObject:protocolString])
        {
            accessory = acc;
            break;
        }
    }
    
    // If we found a match, open a session
    if (accessory)
    {
        session = [[EASession alloc] initWithAccessory:accessory
                                           forProtocol:protocolString];
        if (session)
        {
            // Configure and open streams for the session
            // Add to Common Modes to ensure good performance
            [[session inputStream] setDelegate:self];
            [[session inputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                             forMode:NSRunLoopCommonModes];
                                             //forMode:NSDefaultRunLoopMode];
            [[session inputStream] open];
            [[session outputStream] setDelegate:self];
            [[session outputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                              forMode:NSRunLoopCommonModes];
                                              //forMode:NSDefaultRunLoopMode];
            [[session outputStream] open];
            streamReady = true;
        }
    }
    return session;
}

#pragma mark - Stream delegate methods

- (void)stream:(NSStream*)stream handleEvent:(NSStreamEvent)streamEvent
{
    dispatch_async(_receiveQueue, ^{
        uint8_t buf[20];
        NSInteger bytesRead = 0;
        
        switch (streamEvent)
        {
            case NSStreamEventHasBytesAvailable:
            {
                // Get bytes from the stream and put them into buf for processing
                while((bytesRead = [(NSInputStream *)stream read:buf maxLength:sizeof(buf)]))
                {
                    if(rxData == nil) rxData = [NSMutableData data];
                    [rxData appendBytes:buf length:bytesRead];
                }
                
                // Process received data
                // Minimum data packet for local purposes is 2 bytes
                NSRange r = {0,2};
                while ((r.location + r.length) <= rxData.length) {
                    r.length = rxData.length - r.location;
                    bytesRead = [self readData:[rxData subdataWithRange:r]];
                    r.location += bytesRead;
                }
                
                // If all data has been processed, release the receiver
                if(r.location >= [rxData length])
                {
                    rxData = nil;
                }
                else
                {
                    // Otherwise reset it with the remaining bytes
                    r.length = rxData.length - r.location;
                    [rxData setData:[rxData subdataWithRange:r]];
                }
            }
                break;
            case NSStreamEventHasSpaceAvailable:
            {
                // Send any queued commands
                @synchronized(self)
                {
                    [self transmitBytes];
                }
            }
                break;
            case NSStreamEventErrorOccurred:
            {
                NSLog(@"Stream error occured");
            }
                break;
            default:
                break;
        }
    });
}


#pragma mark - Stream handling functions

- (void)queueTxBytes:(NSData *)buf
{
	if([self isConnected])
	{
		if(txData!=nil)
		{
			[txData appendData:buf];
		}
		else
		{
            txData = [NSMutableData new];
			[txData appendData:buf];
			if([[eas outputStream] hasSpaceAvailable])
			{
				@synchronized(self)
				{
					[self transmitBytes]; // Start sending
				}
			}
		}
	}    
}

- (void)transmitBytes
{
    int bytesSent;
    
    if(txData != nil)
    {
        if([txData length])
        {
            bytesSent = [[eas outputStream] write:[txData bytes] maxLength:[txData length]];

            if (bytesSent < [txData length])
			{
                // Send the rest
				NSRange unsentRange;
				unsentRange.location = bytesSent;
				unsentRange.length = [txData length] - bytesSent;
				[txData setData:[txData subdataWithRange:unsentRange]];
            }
            else
			{
				txData = nil;
            }
        }
    }
}


#pragma mark - External Accessory Identification Tokens

- (NSString *)name { return (eas)?eas.accessory.name:@"-"; }
- (NSString *)manufacturer { return (eas)?eas.accessory.manufacturer:@"-";}
- (NSString *)modelNumber {return (eas)?eas.accessory.modelNumber:@"-";}
- (NSString *)serialNumber {return (eas)?eas.accessory.serialNumber:@"-";}
- (NSString *)firmwareRevision {return (eas)?eas.accessory.firmwareRevision:@"-";}
- (NSString *)hardwareRevision {return (eas)?eas.accessory.hardwareRevision:@"-";}


#pragma mark - Memory management

- (void)dealloc
{
    if (rxData) {
        rxData = nil;
    }
}
@end
