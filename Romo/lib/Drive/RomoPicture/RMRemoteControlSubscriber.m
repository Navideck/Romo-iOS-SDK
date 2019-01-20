//
//  RMRomoteControlSubscriber.m
//  Romo
//

#import "RMRemoteControlSubscriber.h"
#import "RMMessage.h"
#import "RMPacket.h"

@interface RMRemoteControlSubscriber ()

@property (nonatomic, strong) RMSocket *socket;
@property (nonatomic, strong) RMAddress *peerAddress;

@end

@implementation RMRemoteControlSubscriber

+ (RMRemoteControlSubscriber *)subscriberWithService:(RMRemoteControlService *)service
{
    return [[RMRemoteControlSubscriber alloc] initWithService:service];
}

- (id)initWithService:(RMService *)service
{
    if (self = [super initWithService:service])
    {
        _peerAddress = [RMAddress addressWithHost:service.address.host port:service.port];
        _socket = [[RMSocket alloc] initDatagramListenerWithPort:service.address.port];
        [_socket setDelegate:self];
    }
    return self;
}

- (void)start
{
    
}

- (void)stop
{
    if (_socket) {
        RMSocket *socket = _socket;
        _socket = nil;
        [socket shutdown];
    }
}

- (void)sendPicture:(UIImage *)picture
{
    @autoreleasepool {
        if (_peerAddress) {
            float compressionQuality = 0.65f;
            NSData *jpegData = UIImageJPEGRepresentation(picture, compressionQuality);
            NSUInteger packetSize = [jpegData sizeWithHeader];
            
            while (packetSize >= 31000 && compressionQuality > 0) {
                compressionQuality -= 0.05f;
                jpegData = UIImageJPEGRepresentation(picture, compressionQuality);
                packetSize = [jpegData sizeWithHeader];
            }
            
            RMPacket *packet = [RMPacket packetWithMessage:[RMMessage messageWithContent:0 data:jpegData] destination:_peerAddress];
            [_socket sendPacket:packet];
        }
    }
}

- (void)sendExpressionDidStart
{
    @autoreleasepool {
        if (_peerAddress) {
            [_socket sendPacket:[RMPacket packetWithMessage:[RMMessage messageWithContent:1 data:nil] destination:_peerAddress]];
        }
    }
}

- (void)sendExpressionDidFinish
{
    @autoreleasepool {
        if (_peerAddress) {
            [_socket sendPacket:[RMPacket packetWithMessage:[RMMessage messageWithContent:2 data:nil] destination:_peerAddress]];
        }
    }
}

- (void)sendRobotDidFlipOver
{
    @autoreleasepool {
        if (_peerAddress) {
            [_socket sendPacket:[RMPacket packetWithMessage:[RMMessage messageWithContent:3 data:nil] destination:_peerAddress]];
        }
    }
}

- (void)socketConnectionFailed:(RMSocket *)socket
{
    [self stop];
}

- (void)socketClosed:(RMSocket *)socket
{
    [self stop];
}

- (void)socketConnected:(RMSocket *)socket
{
    
}

- (void)socket:(RMSocket *)socket receivedPacket:(RMPacket *)packet
{
    
}

- (void)socket:(RMSocket *)socket didSendPacket:(RMPacket *)packet
{
    
}

- (void)socket:(RMSocket *)socket failedSendingPacket:(RMPacket *)packet
{
}

@end
