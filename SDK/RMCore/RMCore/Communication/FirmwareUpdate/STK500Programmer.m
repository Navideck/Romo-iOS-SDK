//
//  STK500Programmer.m
//  RMCore
//
//  Created on 2013-04-09.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "STK500Programmer.h"


@interface STK500Programmer ()
{
    uint8_t _payloadBuf[ATMEGA_PAGE_SIZE+5];
}

@property (nonatomic) IntelHexImage *fw;
@property (nonatomic) IntelHexLine *currentLine;
@property (nonatomic, weak) RMCoreRobotDataTransport *transport;
@property (nonatomic) NSUInteger currentBlockSize;
@property (nonatomic, readwrite) RMProgrammerState programmerState;
@property (nonatomic, readwrite) RMCommandToRobot sentCommand;
@property (nonatomic, readwrite) float programmerProgress;

@end



@implementation STK500Programmer

@synthesize programmerDelegate = _programmerDelegate;

- (id)initWithTransport:(RMCoreRobotDataTransport *)transport url:(NSString *)fileURL
{
    self = [super init];
    
    if (self) {
        _transport = transport;
        _fw = [[IntelHexImage alloc] initWithContentsOfURL:[NSURL URLWithString:fileURL]];
        
        _fw.blockSize = ATMEGA_PAGE_SIZE;
        _programmerState = RMProgrammerStateInit;
    }
    
    return self;
}


- (void)sendNotification
{
    NSArray *keys = [NSArray arrayWithObjects:@"state", @"progress", nil];
    NSArray *objects = [NSArray arrayWithObjects:[NSNumber numberWithInt:self.programmerState],
                        [NSNumber numberWithFloat:self.programmerProgress], nil];
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotProgrammerNotification
                                                        object:self
                                                      userInfo:dict];
}


- (void)programmerStart
{    
    // If this is called and we are already in the middle of programming or verifying, reset
    if ((self.programmerState == RMProgrammerStateProgramming) ||
        (self.programmerState == RMProgrammerStateVerifying)) {
        self.programmerState = RMProgrammerStateInit;
        self.programmerProgress = 0;
    }
    
    if ((self.programmerState == RMProgrammerStateInit) ||
        (self.programmerState == RMProgrammerStateError)) {
        uint8_t cmd[2] = {RMCommandToRobotSTKReadSignature, RMCommandToRobotSTKCRCEOP};
        [self.transport queueTxBytes:[NSData dataWithBytes:&cmd length:sizeof(cmd)]];
        self.sentCommand = RMCommandToRobotSTKReadSignature;
    }
}


- (void)programmerStarted
{
    self.programmerState = RMProgrammerStateProgramming;
    [self sendNotification];
}


- (void)programmerAbort
{
    self.programmerState = RMProgrammerStateAbort;
    
    [self sendNotification];
}


- (void)loadFirstBlock
{
    [self.fw resetDataBufOffset];
    self.currentBlockSize = [self.fw readCurrentBlock:_payloadBuf+4];
}


- (BOOL)loadNextBlock
{
    [self.fw incrementBlockIndex];
    self.currentBlockSize = [self.fw readCurrentBlock:_payloadBuf+4];
    
    return self.currentBlockSize ? true : false;
}


- (void)sendCurrentBlockAddress
{
    uint8_t cmd[4] = {RMCommandToRobotSTKLoadAddress, self.fw.wordAddress.lowByte, self.fw.wordAddress.highByte, RMCommandToRobotSTKCRCEOP};
    [self.transport queueTxBytes:[[NSData alloc] initWithBytes:&cmd length:sizeof(cmd)]];
    self.sentCommand = RMCommandToRobotSTKLoadAddress;
}


- (void)programCurrentBlock
{
    _payloadBuf[0] = RMCommandToRobotSTKProgramPage;
    _payloadBuf[1] = 0; // MSB of size will always be 0
    _payloadBuf[2] = self.currentBlockSize;
    _payloadBuf[3] = 'F'; // F for Flash, E for EEPROM, which we don't support
    _payloadBuf[self.currentBlockSize+4] = RMCommandToRobotSTKCRCEOP;
    
    NSData *blk = [[NSData alloc] initWithBytes:_payloadBuf length:self.currentBlockSize+5];
    [self.transport queueTxBytes:blk];
    
    self.sentCommand = RMCommandToRobotSTKProgramPage;
    self.programmerProgress = (float)self.fw.blockIndex/(float)self.fw.blockCount;
    [self sendNotification];
}


- (void)requestCurrentBlock
{
    _payloadBuf[0] = RMCommandToRobotSTKReadPage;
    _payloadBuf[1] = 0; // MSB of size will always be 0
    _payloadBuf[2] = self.currentBlockSize;
    _payloadBuf[3] = 'F'; // F for Flash, E for EEPROM, which we don't support
    _payloadBuf[4] = RMCommandToRobotSTKCRCEOP;
    
    [self.transport queueTxBytes:[[NSData alloc] initWithBytes:_payloadBuf length:5]];
    self.sentCommand = RMCommandToRobotSTKReadPage;
}


- (void)verifyCurrentBlock:(NSData *)blk
{
    NSData *currentBlock = [self.fw readCurrentBlock];
    
    if (![currentBlock isEqualToData:blk]) {
        self.programmerState = RMProgrammerStateError;
        self.programmerProgress = 0;
        
        [self sendNotification];
        return;
    }
    
    self.programmerProgress = (float)self.fw.blockIndex/(float)self.fw.blockCount;
    [self sendNotification];
}


- (void)programmerDataReceived:(NSData *)data
{
 	uint8_t buf[1];
    NSRange r;
    
    if (self.programmerState == RMProgrammerStateAbort) {
        return;
    }
    
    r.location = data.length-1;
    r.length = 1;
    
    [data getBytes:buf range:r];
    
    if (buf[0] != RMCommandToRobotSTKOK) {
        return;
    }
    
    switch(self.sentCommand) {
        case RMCommandToRobotSTKReadSignature:
            [self programmerStarted];
            // we don't really do anything with this right now, but it's a good starting point
            [self loadFirstBlock];
            [self sendCurrentBlockAddress];
            break;
            
        case RMCommandToRobotSTKReadPage:
            r.location = 0;
            r.length = data.length-1;
            [self verifyCurrentBlock:[data subdataWithRange:r]];
            
        case RMCommandToRobotSTKProgramPage:
            // if attempting to get the next block results in 0 bytes, then we are done with this programming step
            if (![self loadNextBlock]) {
                if (self.programmerState == RMProgrammerStateProgramming) {
                    self.programmerState = RMProgrammerStateVerifying;
                    [self loadFirstBlock];
                } else if (self.programmerState == RMProgrammerStateVerifying) {
                    self.programmerState = RMProgrammerStateDone;
                    [self sendNotification];
                    return;
                }
                
            }
            [self sendCurrentBlockAddress];
            break;
            
        case RMCommandToRobotSTKLoadAddress:
            // we received an ACK for loading the address, so now send the data
            if (self.programmerState == RMProgrammerStateProgramming) {
                [self programCurrentBlock];
            } else if (self.programmerState == RMProgrammerStateVerifying) {
                [self requestCurrentBlock];
            }
            break;
        default:
            break;
    }
}


@end
