
//
//  AVSubscriber.m
//  RomoLibrary
//
//

#import "RAVSubscriber.h"
#import "RAVVideoInput.h"
#import <CocoaLumberjack/DDLog.h>
#import "RMDataPacket.h"
#import <Romo/UIDevice+Romo.h>
#define SUBSCRIBER_NAME        @"AVSubscriber"
#define SUBSCRIBER_PORT        @"21345"
#define SUBSCRIBER_PROTOCOL    PROTOCOL_UDP

@interface RAVSubscriber () {    
    dispatch_queue_t _dispatchQueue;
}

@property (nonatomic, readwrite, strong) RAVVideoInput *videoInput;
@property (nonatomic, strong) RMDataSocket *socket;
@property (nonatomic, strong) RMAddress *peerAddress;

- (void)getDeviceInfo:(RMDataPacket *)dataPacket;

@end

@implementation RAVSubscriber

+ (RAVSubscriber *)subscriberWithService:(RAVService *)service
{
    return [[RAVSubscriber alloc] initWithService:service];
}

- (id)initWithService:(RMService *)service
{
    self = [super initWithService:service];
    if (self) {
        _peerAddress = [RMAddress addressWithHost:service.address.host port:service.port];
        
        _socket = [[RMDataSocket alloc] initDatagramListenerWithPort:SUBSCRIBER_PORT];
        self.socket.delegate = self;

        _videoInput = [RAVVideoInput input];
        self.videoInput.inputDelegate = self;

        _dispatchQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

- (void)dealloc
{
    [self stop];
    
    _videoInput = nil;
}

- (void)start
{
    RMDataPacket *startPacket = [[RMDataPacket alloc] initWithType:DATA_TYPE_OTHER];
    startPacket.destination = _peerAddress;
    
    [_socket sendDataPacket:startPacket];
    [_videoInput start];
}

- (void)stop
{
    [self.videoInput stop];
    
    if (_socket) {
        RMDataSocket *socket = _socket;
        _socket = nil;
        [socket shutdown];
    }
}

- (void)dataSocketConnectionFailed:(RMDataSocket *)dataSocket
{
    [self stop];
}

- (void)dataSocketClosed:(RMDataSocket *)dataSocket
{
    [self stop];
}

- (void)dataSocket:(RMDataSocket *)dataSocket receivedDataPacket:(RMDataPacket *)dataPacket
{
    switch (dataPacket.type) {            
        case DATA_TYPE_OTHER:
            [self getDeviceInfo:dataPacket];
            break;
            
        default:
            break;
    }
}

//- (void)capturedFrame:(const void *)frame length:(uint32_t)length pts:(CMTime)pts
- (void)capturedFrame:(const void *)frame length:(uint32_t)length
{
    @autoreleasepool {
        if (self.peerAddress) {
            RMDataPacket *packet = [RMDataPacket dataPacketWithType:DATA_TYPE_VIDEO data:frame dataSize:length destination:_peerAddress];
            [self.socket sendDataPacket:packet];
        }
    }
}

- (void)audioPacketReady:(RMDataPacket *)dataPacket
{
    if (self.peerAddress) {
        dataPacket.destination = self.peerAddress;
        [self.socket sendDataPacket:dataPacket];
    }
}

- (void)getDeviceInfo:(RMDataPacket *)dataPacket
{
    char deviceInfoCString[dataPacket.dataSize];
    strcpy(deviceInfoCString, dataPacket.data);
    
    NSString *deviceInfo = [[NSString alloc] initWithCString:deviceInfoCString encoding:NSUTF8StringEncoding];
    
    // Check if the device info has a ## and app version appended
    // this is *very* hacky but needed for legacy support
    // v2.0.1 of the app doesn't check for app version compatability, so we see if the device appended it's
    //    app version. if not, we know it must have been 2.0.1.
    NSRange hashtagRange = [deviceInfo rangeOfString:@"##"];
    if (hashtagRange.length == 0 || deviceInfo.length < hashtagRange.location || deviceInfo.length < 3) {
        return;
    } else {
        deviceInfo = [deviceInfo substringToIndex:hashtagRange.location];
    }

    NSString *deviceModel = [deviceInfo substringToIndex:deviceInfo.length-2];

    BOOL selfIsSlow = ![[UIDevice currentDevice] isFastDevice];
    BOOL isSlow = selfIsSlow || ([deviceModel isEqualToString:@"iPod4"] || [deviceModel isEqualToString:@"iPhone4"]);
    BOOL isMedium = !isSlow && ([deviceModel isEqualToString:@"iPhone4S"] || [deviceModel isEqualToString:@"iPad2"]);
    BOOL isFast = !isSlow && !isMedium;
    
    if (isFast) {
        self.videoInput.videoQuality = RMVideoQualityHigh;
    } else if (isMedium) {
        self.videoInput.videoQuality = RMVideoQualityDefault;
    } else {
        self.videoInput.videoQuality = RMVideoQualityLow;
    }
}

@end
