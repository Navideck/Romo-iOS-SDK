//
//  Session.m
//  Romo
//

#import "RMSession.h"
#import "RMSessionManager.h"
#import "RMAddress.h"
#import "RMMessage.h"
#import "RMPacket.h"
#import "RMPeer.h"
#import "RMSocket.h"
#import "RMService.h"

typedef enum {
    MESSAGE_ID_REQUEST,
    MESSAGE_ID_RESPONSE,
    
    MESSAGE_SESSION_PAUSING,
    MESSAGE_SESSION_RESUMING,
    
    MESSAGE_CALL_ACCEPTED,
    MESSAGE_CALL_DECLINED,
    MESSAGE_CALL_ENDED,
    
    MESSAGE_SERVICE_START,
    MESSAGE_SERVICE_STOP
} SessionMessage;

@interface RMSession () {
    RMSocket *_connectionSocket;
    NSMutableDictionary *_services;
}

- (void)sessionPaused;
- (void)sessionResumed;

@end

#pragma mark -
#pragma mark - Implementation (Session) --

@implementation RMSession

#pragma mark - Creation --

+ (RMSession *)sessionWithSocket:(RMSocket *)socket
{
    return [[RMSession alloc] initWithSocket:socket];
}

+ (RMSession *)sessionWithRemotePeer:(RMPeer *)peer localIdentity:(RMPeer *)identity
{
    return [[RMSession alloc] initWithRemotePeer:peer localIdentity:identity];
}

#pragma mark - Initialization --

- (id)initWithSocket:(RMSocket *)socket
{
    if (self = [super init])
    {
        _connectionSocket = socket;
        [_connectionSocket setDelegate:self];
        _state = STATE_INITIATED;
        
        _services = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (id)initWithRemotePeer:(RMPeer *)peer localIdentity:(RMPeer *)identity
{
    self = [super init];
    if (self) {
        _remotePeer = peer;
        _localIdentity = identity;
        
        _connectionSocket = [[RMSocket alloc] initSocketWithType:SOCK_STREAM withAddress:[peer address]];
        [_connectionSocket setDelegate:self];
        [_connectionSocket connect];
        
        _state = STATE_PENDING;
        
        _services = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
    
    _dataSocket = nil;
    _localIdentity = nil;
    _remotePeer = nil;
}

#pragma mark - Methods --

- (void)requestIdentity
{
    [_connectionSocket sendPacket:[RMPacket packetWithMessage:[RMMessage messageWithContent:MESSAGE_ID_REQUEST]]];
}

- (void)start
{    
    if (_state == STATE_INITIATED) {
        [[RMSessionManager shared] setActiveSession:self];
        
        [_connectionSocket sendPacket:[RMPacket packetWithMessage:[RMMessage messageWithContent:MESSAGE_CALL_ACCEPTED]]];
        _state = STATE_CONNECTED;
        
        if ([self.delegate respondsToSelector:@selector(sessionBegan:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate sessionBegan:self];
            });
        }
    }
}

- (void)resume
{
    if (_state == STATE_PAUSED)
    {
        // Ask the other side to resume:
        [_connectionSocket sendPacket:[RMPacket packetWithMessage:[RMMessage messageWithContent:MESSAGE_SESSION_RESUMING]]];
    }
}

- (void)pause
{
    if (_state == STATE_CONNECTED)
    {
        // Tell the other side we're pausing:
        [_connectionSocket sendPacket:[RMPacket packetWithMessage:[RMMessage messageWithContent:MESSAGE_SESSION_PAUSING]]];
        // Pause us immediately:
        [self sessionPaused];
    }
}

- (void)stop
{
    if (_state != STATE_DISCONNECTED) {
        if ([RMSessionManager shared].activeSession == self) {
            [RMSessionManager shared].activeSession = nil;
        }

        if ([_delegate respondsToSelector:@selector(sessionEnded:)]) {
            id<RMSessionDelegate> delegate = self.delegate;
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate sessionEnded:nil];
            });
        }
        
        _connectionSocket.delegate = nil;
        [_connectionSocket shutdown];
        _connectionSocket = nil;
        _state = STATE_DISCONNECTED;
    }
}

- (void)startService:(RMService *)service
{    
    if (_state == STATE_CONNECTED)
    {
        _services[service.name] = service;
        [_connectionSocket sendPacket:[RMPacket packetWithMessage:[RMMessage messageWithContent:MESSAGE_SERVICE_START package:service]]];
        [service start];
        
        if ([_delegate respondsToSelector:@selector(session:startedService:)])
            [_delegate session:self startedService:service];
    }
}

- (void)stopService:(RMService *)service
{
    if (service) {
        [_connectionSocket sendPacket:[RMPacket packetWithMessage:[RMMessage messageWithContent:MESSAGE_SERVICE_STOP package:service]]];
        [service stop];
        
        [_services removeObjectForKey:service.name];
    }
}

- (void)sessionPaused
{
    _state = STATE_PAUSED;
    
    // Store this Session in the SessionManager for retrieval later:
    [[RMSessionManager shared] setActiveSession:nil];
    [[RMSessionManager shared] setPausedSession:self];
    
    if ([_delegate respondsToSelector:@selector(sessionPaused)])
        [_delegate sessionPaused:self];
}

- (void)sessionResumed
{
    _state = STATE_CONNECTED;
    
    // Remove this Session from the SessionManager:
    [[RMSessionManager shared] setActiveSession:self];
    [[RMSessionManager shared] setPausedSession:nil];
    
    if ([_delegate respondsToSelector:@selector(sessionResumed)])
        [_delegate sessionResumed:self];
}

#pragma mark - SocketDelegate --

-(void)socket:(RMSocket *)socket receivedPacket:(RMPacket *)packet
{
    RMMessage *message = [packet message];
    RMService *service = nil;
    
    switch ([message content])
    {            
        case MESSAGE_ID_REQUEST:
            [_connectionSocket sendPacket:[RMPacket packetWithMessage:[RMMessage messageWithContent:MESSAGE_ID_RESPONSE package:_localIdentity]]];
            break;
            
        case MESSAGE_ID_RESPONSE:
            [self setRemotePeer:(RMPeer *) [RMPeer deserializeData:[message package]]];
            if ([_delegate respondsToSelector:@selector(session:receivedPeerIdentity:)])
                [_delegate session:self receivedPeerIdentity:_remotePeer];
            break;
            
        case MESSAGE_SESSION_PAUSING:
            [self sessionPaused];
            break;
            
        case MESSAGE_SESSION_RESUMING:
            [self resume];
            [self sessionResumed];
            break;
            
        case MESSAGE_CALL_ACCEPTED:
            _state = STATE_CONNECTED;
            if ([_delegate respondsToSelector:@selector(sessionBegan:)])
                [_delegate sessionBegan:self];
            
            break;  
            
        case MESSAGE_CALL_DECLINED:
            _state = STATE_DISCONNECTED;
            _connectionSocket = nil;
            if ([_delegate respondsToSelector:@selector(sessionEnded:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate sessionEnded:self];
                });
            }
            break;
            
        case MESSAGE_CALL_ENDED:
            _state = STATE_DISCONNECTED;
            _connectionSocket = nil;
            if ([_delegate respondsToSelector:@selector(sessionEnded:)])
                [_delegate sessionEnded:self];
            break;
            
        case MESSAGE_SERVICE_START:
            service = (RMService *) [RMService deserializeData:[message package]];
            [service setAddress:[RMAddress addressWithHost:[[packet source] host] port:[service port]]];
            if ([_delegate respondsToSelector:@selector(session:receivedService:)])
                [_delegate session:self receivedService:service];
            break;
            
        case MESSAGE_SERVICE_STOP:
            service = (RMService *) [RMService deserializeData:[message package]];
            if ([_delegate respondsToSelector:@selector(session:finishedService:)])
                [_delegate session:self finishedService:service];
            break;
    }
}

- (void)socketConnected:(RMSocket *)socket
{
    
}

- (void)socketConnectionFailed:(RMSocket *)socket
{
    
}

- (void)socketClosed:(RMSocket *)socket
{
    _connectionSocket = nil;
    [self stop];
}

@end
