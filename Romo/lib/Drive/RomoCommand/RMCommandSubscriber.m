//
//  CommandSubscriber.m
//  Romo
//

#import "RMCommandSubscriber.h"
#import "RMPacket.h"

static const float kSendRate = 0.05;              // 20Hz send rate for motor commands

@interface RMCommandSubscriber () {
    dispatch_queue_t _commandQueue;
    dispatch_source_t _commandTimer;
    
    float _tiltMotorPower;
    DriveControlParameters _driveCommandParams;
}

@property (nonatomic, strong) RMSocket *socket;
@property (nonatomic, strong) RMAddress *peerAddress;

@end

@implementation RMCommandSubscriber

@synthesize socket=_socket, peerAddress=_peerAddress;

+ (RMCommandSubscriber *)subscriberWithService:(RMCommandService *)service
{
    return [[RMCommandSubscriber alloc] initWithService:service];
}

- (id)initWithService:(RMService *)service
{
    self = [super initWithService:service];
    if (self) {
        _peerAddress = [RMAddress addressWithHost:service.address.host port:service.port];
        
        _socket = [[RMSocket alloc] initDatagramListenerWithPort:service.address.port];
        _socket.delegate = self;
        
        // Initialize GCD queue for commands
        _commandQueue = dispatch_queue_create("com.romotive.commandQueue", NULL);
        
        // Initialize GCD-based timer for rate limiting
        _commandTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _commandQueue);
        if (_commandTimer) {
            dispatch_source_set_timer(_commandTimer,
                                      dispatch_time(DISPATCH_TIME_NOW, kSendRate * NSEC_PER_SEC),
                                      kSendRate * NSEC_PER_SEC, // kSendRate interval
                                      NSEC_PER_MSEC);   // 1ms leeway
            
            // Accessing vars within the block retains them, and indirectly retains self, and therefore self
            //   will never dealloc and the socket will not be freed.
            // In order to keep the block from retaining self, we need to use a weak reference within it.
            // By creating a new strong reference inside the block, we can hold onto self during execution,
            //   but that hold releases once the block completes, and self can then dealloc at will.
            __weak RMCommandSubscriber *weakSelf = self;
            dispatch_source_set_event_handler(_commandTimer, ^{
                RMCommandSubscriber *strongSelf = weakSelf;
                if (strongSelf) {
                    if (strongSelf->_socket) {
                        // send motor commands
                        RMCommandMessage *messageTiltPower = [RMCommandMessage messageWithTiltMotorPower:strongSelf->_tiltMotorPower];
                        [strongSelf->_socket sendPacket:[RMPacket packetWithMessage:messageTiltPower
                                                                         destination:strongSelf->_peerAddress]];
                        
                        RMCommandMessage *messageDriveCommand = [RMCommandMessage messageWithDriveParameters:strongSelf->_driveCommandParams];
                        [strongSelf->_socket sendPacket:[RMPacket packetWithMessage:messageDriveCommand
                                                                         destination:strongSelf->_peerAddress]];
                    } else {
                        // The socket has closed, so no need to keep spinning
                        NSLog(@"RMCommandSubscriber -commandTimerBlock: no socket");
                        dispatch_source_cancel(strongSelf->_commandTimer);
                    }
                }
            });
            dispatch_resume(_commandTimer);
        }
    }
    
    return self;
}

- (void)dealloc
{
    [self stop];
}

- (void)start
{
    // Don't have to do anything here.
}

- (void)stop
{
    if (_commandTimer) {
        dispatch_source_cancel(_commandTimer);
        _commandTimer = nil;
    }
    if (_socket) {
        RMSocket *socket = _socket;
        _socket = nil;
        [socket shutdown];
    }
}

- (void)sendTankSlidersLeft:(float)left right:(float)right
{
    DriveControlParameters parameters;
    parameters.controlType = DRIVE_CONTROL_TANK;
    parameters.leftSlider = left;
    parameters.rightSlider = right;
    
    [self sendDriveWithParameters:parameters];
}

- (void)sendDpadSector:(RMDpadSector)sector
{
    DriveControlParameters parameters;
    parameters.controlType = DRIVE_CONTROL_DPAD;
    parameters.sector = sector;
    [self sendDriveWithParameters:parameters];
}

- (void)sendJoystickDistance:(float)distance angle:(float)angle
{
    DriveControlParameters parameters;
    parameters.controlType = DRIVE_CONTROL_JOY;
    parameters.distance = distance;
    parameters.angle = angle;
    [self sendDriveWithParameters:parameters];
}

- (void)sendTiltMotorPower:(float)tiltMotorPower
{
    // Store value for next loop of _commandTimer
    dispatch_async(_commandQueue, ^{
        self->_tiltMotorPower = tiltMotorPower;
    });
}

- (void)sendDriveWithParameters:(DriveControlParameters)parameters
{
    // Store value for next loop of _commandTimer
    dispatch_async(_commandQueue, ^{
        self->_driveCommandParams = parameters;
    });
}

- (void)sendExpression:(RMCharacterExpression)expression
{
    @autoreleasepool {
        RMCommandMessage *message = [RMCommandMessage messageWithExpression:expression];
        [_socket sendPacket:[RMPacket packetWithMessage:message destination:_peerAddress]];
    }
}

- (void)sendTakePicture
{
    @autoreleasepool {
        RMCommandMessage *message = [RMCommandMessage messageToTakePicture];
        [_socket sendPacket:[RMPacket packetWithMessage:message destination:_peerAddress]];
    }
}

- (void)socketConnected:(RMSocket *)socket
{
    NSLog(@"Subscriber connected.");
}

- (void)socketConnectionFailed:(RMSocket *)socket
{
    [self stop];
}

- (void)socketClosed:(RMSocket *)socket
{
    NSLog(@"CommandSubscriber -socketClosed");
    [self stop];
}

- (void)socket:(RMSocket *)socket receivedPacket:(RMPacket *)packet
{
    // Not currently receiving packets.
}

- (void)socket:(RMSocket *)socket didSendPacket:(RMPacket *)packet
{
    // Don't care at the moment.
}

- (void)socket:(RMSocket *)socket failedSendingPacket:(RMPacket *)packet
{
    NSLog(@"CommandMessage failed to be sent...");
}

@end
