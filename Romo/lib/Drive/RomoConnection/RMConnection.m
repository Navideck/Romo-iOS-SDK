//
//  Connection.m
//  Romo
//

#import "RMConnection.h"
#import "RMSession.h"

#define LOCAL_LISTEN_PORT @"21131"

@implementation RMConnection

#pragma mark - Creation

+ (RMConnection *)connection;
{
    return [[RMConnection alloc] init];
}

#pragma mark - Initialization

- (id)init
{
    self = [super init];
    if (self) {
        _peerManager = [RMPeerManager managerWithPort:LOCAL_LISTEN_PORT];
        [_peerManager setDelegate:self];
        
        _listener = [RMListener listenerWithPort:LOCAL_LISTEN_PORT];
        [_listener setDelegate:self];
    }
    
    return self;
}

- (void)dealloc
{
    _peerManager = nil;
    _activeSession = nil;
    _listener = nil;
}

#pragma mark - Methods

- (void)startBroadcastWithIdentity:(RMPeer *)identity
{
    [_peerManager startBroadcastWithIdentity:identity];
}

- (void)shutdownBroadcast
{
    [_peerManager shutdownBroadcast];
}

- (void)startListening
{
    [_peerManager startListening];
}

- (void)restartBroadcast
{
    [_peerManager restartBroadcast];
}

- (void)updateIdentity:(RMPeer *)identity
{
    [_peerManager updateIdentity:identity];
}

- (void)sessionStarted:(RMSession *)session
{
    _activeSession = session;
    [self shutdownBroadcast];
}

- (void)sessionStopped:(RMSession *)session
{
    _activeSession = nil;
    [self restartBroadcast];
}

#pragma mark - ListenerDelegate

- (void)sessionInitiated:(RMSession *)session
{
    [_delegate sessionInitiated:session];
}

#pragma mark - PeerDelegate

- (void)peerAdded:(RMPeer *)peer
{
    [_delegate peerAdded:peer];
}

- (void)peerUpdated:(RMPeer *)peer
{
    [_delegate peerUpdated:peer];
}

- (void)peerRemoved:(RMPeer *)peer
{
    [_delegate peerRemoved:peer];
}

@end
