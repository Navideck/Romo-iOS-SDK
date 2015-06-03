//
//  RMRomoteControlService.m
//  Romo
//

#import "RMRemoteControlService.h"
#import "RMRemoteControlSubscriber.h"
#import "RMPacket.h"

#define SERVICE_NAME        @"PictureSendingService"
#define SERVICE_PORT        @"21355"
#define SERVICE_PROTOCOL    PROTOCOL_UDP

@interface RMRemoteControlService ()

@property (nonatomic, strong) RMSocket *socket;
@property (nonatomic, strong) RMAddress *peerAddress;

- (void)prepareNetworking;

@end

@implementation RMRemoteControlService

+ (RMRemoteControlService *)service
{
    return [[RMRemoteControlService alloc] init];
}

- (id)init
{
    if (self = [super initWithName:SERVICE_NAME port:SERVICE_PORT protocol:SERVICE_PROTOCOL])
    {
        [self prepareNetworking];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
    _peerAddress = nil;
    _socket = nil;
}

- (void)prepareNetworking
{
    _socket = [[RMSocket alloc] initDatagramListenerWithPort:SERVICE_PORT];
    [_socket setDelegate:self];
}

- (RMSubscriber *)subscribe
{
    return [RMRemoteControlSubscriber subscriberWithService:self];
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

- (void)socketConnectionFailed:(RMSocket *)socket
{
    [self stop];
}

- (void)socketClosed:(RMSocket *)socket
{
    _socket = nil;
    [self stop];
}

- (void)socket:(RMSocket *)socket receivedPacket:(RMPacket *)packet
{
    switch (packet.message.content) {
        case 0:
            [self.delegate didReceivePicture:[UIImage imageWithData:packet.message.package]];
            break;
            
        case 1: {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self.delegate remoteExpressionAnimationDidStart];
            });
            break;
        }
    
        case 2: {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self.delegate remoteExpressionAnimationDidFinish];
            });
            break;
        }
            
        case 3: {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self.delegate robotDidFlipOver];
            });
            break;
        }
            
        default:
            break;
    }
}

@end
