//
//  AVService.m
//  RomoLibrary
//
//

#import "RAVService.h"
#import "RAVSubscriber.h"
#import "RMDataPacket.h"
#import <Romo/UIDevice+Romo.h>

#define SERVICE_NAME        @"AVService"
#define SERVICE_PORT        @"21345"
#define SERVICE_PROTOCOL    PROTOCOL_UDP

@interface RAVService ()

@property (nonatomic, strong) RMDataSocket *socket;
@property (nonatomic, strong) RMAddress *peerAddress;
@property (nonatomic, strong) RAVVideoOutput *videoOutput;

- (void)prepareNetworking;
- (void)prepareVideo;

- (void)sendDeviceInfo;

@end

@implementation RAVService

@synthesize socket=_socket, peerAddress=_peerAddress;

+ (RAVService *)service
{
    return [[RAVService alloc] init];
}

- (id)init
{
    self = [super initWithName:SERVICE_NAME port:SERVICE_PORT protocol:SERVICE_PROTOCOL];
    if (self) {
        [self prepareNetworking];
        [self prepareVideo];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
    [self.videoOutput stop];
}

- (void)prepareNetworking
{
    _socket = [[RMDataSocket alloc] initDatagramListenerWithPort:SERVICE_PORT];
    _socket.delegate = self;
}

- (void)prepareVideo
{
    self.videoOutput = [[RAVVideoOutput alloc] init];
}

#pragma mark - Service --

- (RMSubscriber *)subscribe
{
    return [RAVSubscriber subscriberWithService:self];
}

- (void)start
{

}

- (void)stop
{
    if (_socket) {
        RMDataSocket *socket = _socket;
        _socket = nil;
        [socket shutdown];
    }
}

- (void)dataSocket:(RMDataSocket *)socket receivedDataPacket:(RMDataPacket *)dataPacket
{
    switch (dataPacket.type) {
        case DATA_TYPE_OTHER: {
            _peerAddress = [RMAddress addressWithHost:dataPacket.source.host port:SERVICE_PORT];
            [self sendDeviceInfo];
            break;
        }

        case DATA_TYPE_VIDEO: {
            [self.videoOutput playVideoFrame:[dataPacket extractData] length:dataPacket.dataSize];
            break;
        }
        default:
            break;
    }
}

- (void)dataSocketClosed:(RMDataSocket *)dataSocket
{
    [self stop];   
}

- (void)dataSocketConnectionFailed:(RMDataSocket *)dataSocket
{
    [self stop];
}

- (UIView *)peerView
{
    return self.videoOutput.peerView;
}

- (void)sendDeviceInfo
{
    NSString *deviceType = [[UIDevice currentDevice] modelIdentifier];
    
    // Send the device name, then "##"
    // this is very hacky but needed for legacy support
    // v2.0.1 of the app doesn't check for app version compatability, so we see if the device appended a "##".
    //     if not, we know it must have been 2.0.1.
    NSString *deviceInfo = [NSString stringWithFormat:@"%@##",deviceType];
    
    char deviceCString[deviceInfo.length + 1];
    [deviceInfo getCString:deviceCString maxLength:deviceInfo.length + 1 encoding:NSUTF8StringEncoding];
    RMDataPacket *deviceInfoPacket = [[RMDataPacket alloc] initWithType:DATA_TYPE_OTHER data:deviceCString dataSize:(uint32_t)deviceInfo.length + 1 destination:_peerAddress];
    [_socket sendDataPacket:deviceInfoPacket];
}
@end
