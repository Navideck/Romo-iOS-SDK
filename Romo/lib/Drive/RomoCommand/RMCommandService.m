//
//  CommandService.m
//  Romo
//

#import "RMCommandService.h"
#import "RMCommandSubscriber.h"
#import "RMCommandMessage.h"
#import "RMPacket.h"

#define SERVICE_NAME        @"CommandService"
#define SERVICE_PORT        @"21365"
#define SERVICE_PROTOCOL    PROTOCOL_UDP

@interface RMCommandService ()

@property (nonatomic, strong) RMSocket *socket;
@property (nonatomic, strong) RMAddress *peerAddress;

- (void)resetRobot;

- (void)setTiltMotorPower:(float)tiltMotorPower;
- (void)setDriveParameters:(DriveControlParameters)parameters;
- (void)setExpression:(RMCharacterExpression)expression;
- (void)takePicture;

@end

@implementation RMCommandService

+ (RMCommandService *)service
{
    return [[RMCommandService alloc] init];
}

- (id)init
{
    self = [super initWithName:SERVICE_NAME port:SERVICE_PORT protocol:SERVICE_PROTOCOL];
    if (self) {
        _socket = [[RMSocket alloc] initDatagramListenerWithPort:SERVICE_PORT];
        self.socket.delegate = self;
    }
    return self;
}

- (void)dealloc
{
    [self stop];
    _peerAddress = nil;
    _socket = nil;
}

- (void)resetRobot
{
    [self setTiltMotorPower:0.0];

    DriveControlParameters driveControlParams;
    driveControlParams.controlType = DRIVE_CONTROL_DPAD;
    driveControlParams.leftSlider = 0;
    driveControlParams.rightSlider = 0;
    driveControlParams.distance = 0;
    driveControlParams.angle = 0;
    driveControlParams.sector = 0;
    [self setDriveParameters:driveControlParams];
}

- (void)setTiltMotorPower:(float)tiltMotorPower
{
    if ([self.delegate respondsToSelector:@selector(commandReceivedWithTiltMotorPower:)]) {
        __weak id<RMCommandDelegate> delegate = self.delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate commandReceivedWithTiltMotorPower:tiltMotorPower];
        });
    }
}

- (void)setDriveParameters:(DriveControlParameters)parameters
{
    if ([self.delegate respondsToSelector:@selector(commandReceivedWithDriveParameters:)]) {
        __weak id<RMCommandDelegate> delegate = self.delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate commandReceivedWithDriveParameters:parameters];
        });
    }
}

- (void)setExpression:(RMCharacterExpression)expression
{    
    if ([self.delegate respondsToSelector:@selector(commandReceivedWithExpression:)]) {
        __weak id<RMCommandDelegate> delegate = self.delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate commandReceivedWithExpression:expression];
        });
    }
}

- (void)takePicture
{
    if ([self.delegate respondsToSelector:@selector(commandReceivedToTakePicture)]) {
        __weak id<RMCommandDelegate> delegate = self.delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate commandReceivedToTakePicture];
        });
    }
}

- (RMSubscriber *)subscribe
{
    return [RMCommandSubscriber subscriberWithService:self];
}

- (void)start
{
    [self resetRobot];
}

- (void)stop
{
    [self resetRobot];
    
    if (_socket) {
        RMSocket *socket = _socket;
        _socket = nil;
        [socket shutdown];
    }
}

- (void)socketConnected:(RMSocket *)socket
{
    
}

- (void)socketConnectionFailed:(RMSocket *)socket
{
    [self stop];
}

- (void)socketClosed:(RMSocket *)socket
{
    [self stop];
}

- (void)socket:(RMSocket *)socket receivedPacket:(RMPacket *)packet
{
    RMCommandMessage *message = (RMCommandMessage *) [packet message];
    DriveControlParameters driveControlParams;
    
    switch([message content]) {
        case COMMAND_TILT:
            [self setTiltMotorPower:message.tiltMotorPower];
            break;
            
        case COMMAND_EXPRESSION:
            [self setExpression:message.expression];
            break;
            
        case COMMAND_DRIVE:            
            driveControlParams.controlType = message.controlType;
            driveControlParams.leftSlider = message.leftSlider;
            driveControlParams.rightSlider = message.rightSlider;
            driveControlParams.distance = message.distance;
            driveControlParams.angle = message.angle;
            driveControlParams.sector = message.sector;
            
            [self setDriveParameters:driveControlParams];
            break;
            
        case COMMAND_PICTURE:
            [self takePicture];
            break;
            
        case COMMAND_ALL:
            driveControlParams.controlType = message.controlType;
            driveControlParams.leftSlider = message.leftSlider;
            driveControlParams.rightSlider = message.rightSlider;
            driveControlParams.distance = message.distance;
            driveControlParams.angle = message.angle;
            driveControlParams.sector = message.sector;
            
            [self setDriveParameters: driveControlParams];
            [self setTiltMotorPower:message.tiltMotorPower];
            [self setExpression:message.expression];
            break;
            
        default:
            break;
    }
}

- (void)socket:(RMSocket *)socket didSendPacket:(RMPacket *)packet
{
    // Not sending packets yet.
}

- (void)socket:(RMSocket *)socket failedSendingPacket:(RMPacket *)packet
{
    // Not sending packets yet.    
}

@end

