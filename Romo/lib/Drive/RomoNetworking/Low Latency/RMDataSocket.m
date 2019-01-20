//
//  DataSocket.m
//  Romo
//

#import "RMDataSocket.h"
#import "RMAddress.h"
#import "RMDataPacket.h"
#include <string.h>
#import "CocoaLumberjack.h"
#pragma mark - Constants --

#define SEND_BUFFER_SIZE 65535

#pragma mark -
#pragma mark - DataSocket (Private) --

@interface RMDataSocket ()

- (void)setupReadSource;

- (void)connectionSucceeded;
- (void)connectionFailed;

- (void)sendStreamDataPacket:(RMDataPacket *)dataPacket;
- (void)sendDatagramDataPacket:(RMDataPacket *)dataPacket;

- (void)readStream;
- (void)readDatagram;

- (void)readStreamPacketWithBytesAvailable:(NSInteger)bytesAvailable;
- (void)readDatagramPacket;

@end

#pragma mark -
#pragma mark - Implementation (DataSocket) --

@implementation RMDataSocket

#pragma mark - Properties --

@synthesize localAddress=_address;
@synthesize peerAddress=_peerAddress;
@synthesize delegate=_delegate;
@synthesize isConnected=_isConnected;

#pragma mark - Initialization --

- (id)initDataSocketWithType:(SocketType)type withAddress:(RMAddress *)address
{
    self = [super init];
    if (self) {
        self.localAddress = address;
        _socketType = type;
        
        AddressInfo *info = [address infoWithType:type];
        _nativeSocket = socket(info->ai_family, info->ai_socktype, info->ai_protocol);
        
        _readQueue = dispatch_queue_create("com.Romotive.remoteControl.readQueue", DISPATCH_QUEUE_SERIAL);
        _writeQueue = dispatch_queue_create("com.Romotive.remoteControl.writeQueue", DISPATCH_QUEUE_SERIAL);
        
        _readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _nativeSocket, 0, _readQueue);
        
        if (_nativeSocket == -1) {
            NSLog(@"DataSocket() failed!");
            perror( "Error opening file" );
            
            return nil;
        }
        
        int sendSize = SEND_BUFFER_SIZE;
        setsockopt(_nativeSocket, SOL_SOCKET, SO_SNDBUF, &sendSize, sizeof(sendSize));
    }
    
    return self;
}

- (id)initDatagramListenerWithPort:(NSString *)port
{
    RMAddress *address = [RMAddress localAddressWithPort:port];
    
    if (self = [self initDataSocketWithType:SOCK_DGRAM withAddress:address]) {
        [self setupReadSource];
        
        AddressInfo *info = [address infoWithType:SOCK_STREAM];
        
        int yes = 1;
        
        if (setsockopt(_nativeSocket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1) {
            return nil;
        }
        
        struct sockaddr_in *addr = (struct sockaddr_in *) info->ai_addr;
        addr->sin_addr.s_addr = htonl(INADDR_ANY);
        
        
        struct linger lin = {1,0};
        setsockopt(_nativeSocket, SOL_SOCKET, SO_LINGER, &lin, sizeof(struct linger));
        
        if (bind(_nativeSocket, info->ai_addr, info->ai_addrlen) == -1) {
            DDLogError(@"Bind failed: %s", strerror(errno));
            return nil;
        }
        
        _isConnected = YES;
    }
    
    return self;
}

#pragma mark - Methods --

- (void)sendDataPacket:(RMDataPacket *)dataPacket
{
    dispatch_async(_writeQueue, ^{ @autoreleasepool {
        switch (self->_socketType) {
            case SOCK_STREAM:
                [self sendStreamDataPacket:dataPacket];
                break;
                
            case SOCK_DGRAM:
                [self sendDatagramDataPacket:dataPacket];
                break;
                
            default:
                break;
        }
    }});
}

- (void)connect
{
    AddressInfo *info = [_address infoWithType:SOCK_STREAM];
    
    int result = connect(_nativeSocket, info->ai_addr, info->ai_addrlen);
    
    if (result == 0) {
        dispatch_async(_readQueue, ^{ @autoreleasepool {
            self->_isConnected = YES;
            [self setPeerAddress:self->_address];
            [self connectionSucceeded];
        }});
    } else {
        perror("RMDataSocket: connect() failed");
        _isConnected = NO;
        dispatch_async(_readQueue, ^{ @autoreleasepool {
            [self connectionFailed];
        }});
    }
}

- (void)shutdown
{
    if (_isConnected) {
        _isConnected = NO;
        dispatch_source_cancel(_readSource);
        
        if ([_delegate respondsToSelector:@selector(dataSocketClosed:)]) {
            [_delegate dataSocketClosed:self];
        }
    }
}

#pragma mark - Methods (Private) --

- (void)setupReadSource
{
    __weak RMDataSocket *weakSelf = self;
    
    if (_socketType == SOCK_STREAM) {
        dispatch_source_set_event_handler(_readSource, ^{
            [weakSelf readStream];
        });
    } else {
        dispatch_source_set_event_handler(_readSource, ^{
            [weakSelf readDatagram];
        });
    }
    
    dispatch_source_set_cancel_handler(_readSource, ^{
        close(self->_nativeSocket);
    });
    
    dispatch_resume(_readSource);
}

- (void)connectionSucceeded
{
    [self setupReadSource];
    
    if ([_delegate respondsToSelector:@selector(dataSocketConnected:)]) {
        [_delegate dataSocketConnected:self];
    }
}

- (void)connectionFailed
{
    if ([_delegate respondsToSelector:@selector(dataSocketConnectionFailed:)])
        [_delegate dataSocketConnectionFailed:self];
}

- (void)sendDatagramDataPacket:(RMDataPacket *)dataPacket
{
    if (dataPacket.destination == nil)
        return;
    
    SockAddress *addr = dataPacket.destination.sockAddress;
    
    NSUInteger packetSize = dataPacket.packetSize;
    char bytes[packetSize];
    
    [dataPacket serializeToBytes:bytes];
    
    ssize_t charsSent = 0;
    charsSent = sendto(_nativeSocket, bytes, packetSize, 0, addr, addr->sa_len);
    
    if (charsSent == -1) {
        int e = errno;
        perror("sendto");
        NSLog(@"RNTDataSocket: errno = %d",e);
    }
}

- (void)sendStreamDataPacket:(RMDataPacket *)dataPacket
{
    char bytes[dataPacket.packetSize];
    
    [dataPacket serializeToBytes:bytes];
    
    ssize_t charsSent = 0;
    charsSent = send(_nativeSocket, bytes, dataPacket.dataSize, 0);
    
    if (charsSent == -1) {
        int e = errno;
        perror("send");
        NSLog(@"RNTDataSocket: errno = %d",e);
    }
}

- (void)readStream
{
    NSUInteger bytesAvailable = dispatch_source_get_data(_readSource);
    
    if (bytesAvailable > 0) {
        [self readStreamPacketWithBytesAvailable:bytesAvailable];
    } else {
        [self shutdown];
    }
}

- (void)readDatagram
{
    NSUInteger bytesAvailable = dispatch_source_get_data(_readSource);
    
    if (bytesAvailable > 0) {
        [self readDatagramPacket];
    } else {
        [self shutdown];
    }
}

- (void)readStreamPacketWithBytesAvailable:(NSInteger)bytesAvailable
{
    NSInteger charsReceived = 0;
    NSUInteger headerSize = [RMDataPacket headerSize];
    
    if (headerSize > bytesAvailable) {
        NSLog(@"headerSize greater than bytes available");
        return;
    }
    
    char headerBuffer[headerSize];
    charsReceived = recv(_nativeSocket, headerBuffer, headerSize, MSG_PEEK);
    
    if (charsReceived == -1) {
        NSLog(@"Error during recv() for header.");
        return;
    }
    
    uint32_t dataSize = ((uint32_t *)headerBuffer)[1];
    
    if (dataSize > bytesAvailable) {
        return;
    }
    
    char packetSize = headerSize + dataSize;
    char dataBuffer[packetSize];
    
    charsReceived = recv(_nativeSocket, dataBuffer, packetSize, 0);
    
    if (charsReceived == -1) {
        NSLog(@"Error during recv() for body.");
        return;
    }
    
    RMDataPacket *dataPacket = [[RMDataPacket alloc] initWithBytes:dataBuffer];
    
    if (dataPacket && [_delegate respondsToSelector:@selector(dataSocket:receivedDataPacket:)]) {
        [_delegate dataSocket:self receivedDataPacket:dataPacket];
    }
}

- (void)readDatagramPacket
{
    ssize_t charsReceived = 0;
    NSUInteger headerSize = [RMDataPacket headerSize];
    
    char headerBuffer[headerSize];
    
    SockAddress from;
    int fromLength = sizeof(SockAddress);
    
    charsReceived = recvfrom(_nativeSocket, headerBuffer, headerSize, MSG_PEEK, &from, (socklen_t *) &fromLength);
    
    if (charsReceived == -1) {
        NSLog(@"Error during recvfrom() for header.");
        return;
    }
    
    uint32_t dataSize = ((uint32_t *)headerBuffer)[1];
    NSUInteger packetSize = dataSize + headerSize;
    
    char dataBuffer[dataSize + headerSize];
    charsReceived = recvfrom(_nativeSocket, dataBuffer, packetSize, 0, (struct sockaddr *)&from, (socklen_t *)&fromLength);
    
    if (charsReceived == -1) {
        NSLog(@"Error during recvfrom() for body.");
        return;
    }
    
    RMDataPacket *packet = [[RMDataPacket alloc] initWithBytes:dataBuffer];
    packet.source = [RMAddress addressWithSockAddress:&from];
    
    if ([_delegate respondsToSelector:@selector(dataSocket:receivedDataPacket:)]) {
        [_delegate dataSocket:self receivedDataPacket:packet];
    }
}

@end
