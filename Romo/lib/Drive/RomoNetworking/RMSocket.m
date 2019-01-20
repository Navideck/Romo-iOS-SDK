//
//  RMSocket.m
//  Romo
//

#import "RMSocket.h"
#import "RMAddress.h"
#import "RMPacket.h"
#import <string.h>

#pragma mark - Constants

#define SEND_BUFFER_SIZE 32000

#pragma mark -
#pragma mark - Socket (Private)

@interface RMSocket ()

- (void)setupReadSource;

- (void)connectionSucceeded;
- (void)connectionFailed;

- (void)sendStreamPacket:(RMPacket *)packet;
- (void)sendDatagramPacket:(RMPacket *)packet;

- (void)readStream;
- (void)readDatagram;

- (void)readStreamPacketWithBytesAvailable:(NSInteger)bytesAvailable;
- (void)readDatagramPacket;

- (uint32_t)unpackInteger:(uint8_t *)packedBytes offset:(uint32_t)offset;

@end

#pragma mark -
#pragma mark - Implementation (Socket)

@implementation RMSocket

#pragma mark - Initialization

- (id)initSocketWithType:(SocketType)type withAddress:(RMAddress *)address
{
    if (self = [super init])
    {
        _isConnected = NO;
        
        self.localAddress = address;
        
        _socketType = type;
        
        AddressInfo *info = [address infoWithType:type];
        _nativeSocket = socket(info->ai_family, info->ai_socktype, info->ai_protocol);
        
        _readQueue = dispatch_queue_create("com.Romotive.remoteControl.readQueue", DISPATCH_QUEUE_SERIAL);
        _writeQueue = dispatch_queue_create("com.Romotive.remoteControl.writeQueue", DISPATCH_QUEUE_SERIAL);
        
        if (_nativeSocket == -1)
        {
            NSLog(@"Socket() failed!");
            perror( "Error opening file" );
            
            return nil;
        }
        
        int sendSize = SEND_BUFFER_SIZE;
        setsockopt(_nativeSocket, SOL_SOCKET, SO_SNDBUF, &sendSize, sizeof(sendSize));
    }
    
    return self;
}

- (id)initStreamWithNativeSocket:(NativeSocket)socketHandle
{
    self = [super init];
    if (self) {
        _isConnected = YES;
        
        _socketType = SOCK_STREAM;
        _nativeSocket = socketHandle;
        
        _readQueue = dispatch_queue_create("com.Romotive.remoteControl.readQueue", DISPATCH_QUEUE_SERIAL);
        _writeQueue = dispatch_queue_create("com.Romotive.remoteControl.writeQueue", DISPATCH_QUEUE_SERIAL);
        
        struct linger lin = {1,0};
        setsockopt(_nativeSocket, SOL_SOCKET, SO_LINGER, &lin, sizeof(struct linger));
        
        [self setupReadSource];
    }
    return self;
}

- (id)initDatagramListenerWithPort:(NSString *)port
{
    self = [self initSocketWithType:SOCK_DGRAM withAddress:[RMAddress localAddressWithPort:port]];
    if (self) {
        [self setupReadSource];
        
        AddressInfo *info = [self.localAddress infoWithType:SOCK_STREAM];
        
        int yes = 1;
        
        if (setsockopt(_nativeSocket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1)  {
            DDLogError(@"setsockopt failed: %s", strerror(errno));
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
    }
    
    return self;
}

#pragma mark - Methods

- (void)sendPacket:(RMPacket *)packet
{
    dispatch_async(_writeQueue, ^{ @autoreleasepool {
        
        switch (self->_socketType)
        {
            case SOCK_STREAM:
                [self sendStreamPacket:packet];
                break;
                
            case SOCK_DGRAM:
                [self sendDatagramPacket:packet];
                break;
                
            default:
                DDLogError(@"Error: Socket is of unknown type.");
                break;
        }
    }});
}

- (void)connect
{
    AddressInfo *info = [_localAddress infoWithType:SOCK_STREAM];
    
    int result = connect(_nativeSocket, info->ai_addr, info->ai_addrlen);
    
    if (result == 0)
    {
        dispatch_async(_readQueue, ^{ @autoreleasepool {
            self->_isConnected = YES;
            [self setPeerAddress:self->_localAddress];
            [self connectionSucceeded];
        }});
    }
    else
    {
        int e = errno;
        perror("Error during connect.");
        NSLog(@"\t(RNTSocket) errno = %d",e);
        _isConnected = NO;
        dispatch_async(_readQueue, ^{ @autoreleasepool {
            [self connectionFailed];
        }});
    }
}

- (void)shutdown
{
    if (_readSource) {
        dispatch_source_cancel(_readSource);
        _readSource = NULL;
    }
    
    if ([_delegate respondsToSelector:@selector(socketClosed:)]) {
        [_delegate socketClosed:self];
    }
}

#pragma mark - Methods (Private)

- (void)setupReadSource
{
    _readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _nativeSocket, 0, _readQueue);
    
    __weak RMSocket *weakSelf = self;
	dispatch_source_set_event_handler(_readSource, ^{
        @autoreleasepool {
            self->_socketType == SOCK_STREAM ? [weakSelf readStream] : [weakSelf readDatagram];
        }
    });
    
    dispatch_source_set_cancel_handler(_readSource, ^{
        @autoreleasepool {
            close(self->_nativeSocket);
        }
    });
    
    dispatch_resume(_readSource);
}

- (void)connectionSucceeded
{
    [self setupReadSource];
    
    if ([_delegate respondsToSelector:@selector(socketConnected:)]) {
        [_delegate socketConnected:self];
    }
}

- (void)connectionFailed
{
    if ([_delegate respondsToSelector:@selector(socketConnectionFailed:)]) {
        [_delegate socketConnectionFailed:self];
    }
}

- (void)sendDatagramPacket:(RMPacket *)packet
{
    NSData *data = [packet serialize];
    
    char *bytes         = [data bytesWithHeader];
    NSUInteger dataSize   = [data sizeWithHeader];
    
    SockAddress *addr = [[packet destination] sockAddress];
    
    ssize_t charsSent = 0;
    charsSent = sendto(_nativeSocket, bytes, dataSize, 0, addr, addr->sa_len);
    free(bytes);
    
    if (charsSent == -1)
    {
        perror("sendto");
        if ([_delegate respondsToSelector:@selector(socket:failedSendingPacket:)])
            [_delegate socket:self failedSendingPacket:packet];
    }
    else
    {
        if ([_delegate respondsToSelector:@selector(socket:didSendPacket:)])
            [_delegate socket:self didSendPacket:packet];
    }
}

- (void)sendStreamPacket:(RMPacket *)packet
{
    NSData *data = [packet serialize];
    
    char *bytes         = [data bytesWithHeader];
    NSUInteger dataSize   = [data sizeWithHeader];
    
    NSInteger charsSent = 0;
    charsSent = send(_nativeSocket, bytes, dataSize, 0);
    free(bytes);
    
    if (charsSent == -1)
    {
        int e = errno;
        perror("send");
        NSLog(@"RNTSocket: errno = %d",e);
        if ([_delegate respondsToSelector:@selector(socket:failedSendingPacket:)])
            [_delegate socket:self failedSendingPacket:packet];
    }
    else
    {
        if ([_delegate respondsToSelector:@selector(socket:didSendPacket:)])
            [_delegate socket:self didSendPacket:packet];
    }
}

- (void)readStream
{
    if (_readSource) {
        NSUInteger bytesAvailable = dispatch_source_get_data(_readSource);
        
        if (bytesAvailable > 0) {
            [self readStreamPacketWithBytesAvailable:bytesAvailable];
        } else {
            [self shutdown];
        }
    }
}

- (void)readDatagram
{
    if (_readSource) {
        NSUInteger bytesAvailable = dispatch_source_get_data(_readSource);

        if (bytesAvailable > 0) {
            [self readDatagramPacket];
        } else {
            [self shutdown];
        }
    }
}

- (void)readStreamPacketWithBytesAvailable:(NSInteger)bytesAvailable
{
    NSInteger charsReceived = 0;
    NSInteger headerSize = [RMNetworkUtilities headerSize];
    
    if (headerSize > bytesAvailable) {
        return;
    }
    
    char headerBuffer[headerSize];
    charsReceived = recv(_nativeSocket, headerBuffer, headerSize, MSG_PEEK);

    if (charsReceived == -1) {
        return;
    }
    
    uint32_t dataSize = [self unpackInteger:(uint8_t *)headerBuffer offset:0];
    
    if (dataSize > bytesAvailable) {
        return;
    }
    
    charsReceived = recv(_nativeSocket, headerBuffer, headerSize, 0);
    
    char dataBuffer[dataSize];
    charsReceived = recv(_nativeSocket, dataBuffer, dataSize, 0);

    if (charsReceived == -1) {
        return;
    }
    
    NSData *data = [[NSData alloc] initWithBytes:dataBuffer length:dataSize];
    
    if (data) {
        RMPacket *packet = [[RMPacket alloc] initWithData:data source:_peerAddress];
        if (packet != nil && [_delegate respondsToSelector:@selector(socket:receivedPacket:)]) {
            [_delegate socket:self receivedPacket:packet];
        }
    }
}

- (void)readDatagramPacket
{
    ssize_t charsReceived = 0;
    uint32_t headerSize = [RMNetworkUtilities headerSize];
    
    char headerBuffer[headerSize];
    
    SockAddress from;
    int fromLength = sizeof(SockAddress);
    
    charsReceived = recvfrom(_nativeSocket, headerBuffer, headerSize, MSG_PEEK, &from, (socklen_t *) &fromLength);
    
    if (charsReceived == -1) {
        return;
    }
    
    uint32_t dataSize = [self unpackInteger:(uint8_t *)headerBuffer offset:0];
    
    char dataBuffer[dataSize + headerSize];
    charsReceived = recvfrom(_nativeSocket, dataBuffer, dataSize + headerSize, 0, (struct sockaddr *)&from, (socklen_t *)&fromLength);
    
    if (charsReceived == -1) {
        return;
    }
    
    headerSize = sizeof(uint32_t);
    NSData *data = [[NSData alloc] initWithBytes:(dataBuffer + headerSize) length:dataSize];
    RMAddress *address = [[RMAddress alloc] initWithSockAddress:&from];
    
    RMPacket *packet = [[RMPacket alloc] initWithData:data source:address];
    
    if ([_delegate respondsToSelector:@selector(socket:receivedPacket:)]) {
        [_delegate socket:self receivedPacket:packet];
    }
}

- (uint32_t)unpackInteger:(uint8_t *)packedBytes offset:(uint32_t)offset
{
    uint32_t netInt = 0;
    
    netInt |= packedBytes[offset++] << 24;
    netInt |= packedBytes[offset++] << 16;
    netInt |= packedBytes[offset++] << 8;
    netInt |= packedBytes[offset];
    
    return netInt;
}

@end
