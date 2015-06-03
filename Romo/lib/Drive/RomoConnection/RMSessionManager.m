//
//  NetworkingManager.m
//  Romo
//

#import "RMSessionManager.h"
#import "RMConnection.h"
#import "RMSession.h"
#import "RMMessage.h"

#pragma mark - Singleton Instance --

@interface RMSessionManager ()

@property (nonatomic, strong) RMConnection *connection;
@property (nonatomic, strong) NSMutableDictionary *peerListDictionary;
@property (nonatomic) BOOL broadcasting;

@end

@implementation RMSessionManager

#pragma mark - Singleton Access --

+ (RMSessionManager *)shared
{
    static RMSessionManager *instance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RMSessionManager alloc] init];
    });

    return instance;
}

#pragma mark - Initialization --

- (id)init
{
    self = [super init];
    if (self) {
        _peerListDictionary = [NSMutableDictionary dictionary];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationDidEnterBackgroundNotification:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Methods

- (NSArray *)peerList
{
    return [NSArray arrayWithArray:self.peerListDictionary.allValues];
}

- (void)startListeningForRomos
{
    self.connection = [RMConnection connection];
    self.connection.delegate = self;
    [self.connection startListening];
}

- (void)stopListeningForRomos
{
    [self.connection shutdownBroadcast];
    [self.peerListDictionary removeAllObjects];
    self.connection = nil;
}

- (void)startBroadcastWithIdentity:(RMPeer *)identity
{
    self.localIdentity = identity;
    
    self.connection = [RMConnection connection];
    self.connection.delegate = self;
    [self.connection startBroadcastWithIdentity:identity];
    
    self.broadcasting = YES;
}

- (void)updateIdentity:(RMPeer *)identity
{
    self.localIdentity = identity;
    [self.connection updateIdentity:identity];
}

- (void)stopBroadcasting
{
    self.localIdentity = nil;
    [self.connection shutdownBroadcast];
    self.connection = nil;
    
    self.broadcasting = NO;
}

- (RMSession *)initiateSessionWithPeer:(RMPeer *)peer
{
    __autoreleasing RMSession *newSession = [[RMSession alloc] initWithRemotePeer:peer localIdentity:_localIdentity];
    _activeSession = newSession;
    
    return _activeSession;
}

#pragma mark - ConnectionDelegate

- (void)peerAdded:(RMPeer *)peer
{
    self.peerListDictionary[[peer identifier]] = peer;
    
    if ([_managerDelegate respondsToSelector:@selector(peerListUpdated:)]) {
        [_managerDelegate peerListUpdated:self.peerList];
    }
    
    [self.connectionDelegate peerAdded:peer];
}

- (void)peerUpdated:(RMPeer *)peer
{
    if (peer) {
        self.peerListDictionary[[peer identifier]] = peer;
        
        if ([_managerDelegate respondsToSelector:@selector(peerListUpdated:)]) {
            [_managerDelegate peerListUpdated:[self peerList]];
        }
        
        [self.connectionDelegate peerUpdated:peer];
    }
}

- (void)peerRemoved:(RMPeer *)peer
{
    
    if ([_managerDelegate respondsToSelector:@selector(peerListUpdated:)]) {
        [_managerDelegate peerListUpdated:self.peerList];
    }
    
    [self.connectionDelegate peerRemoved:peer];
    
    if (!peer) {
        return;
    }
    
    [self.peerListDictionary removeObjectForKey:peer.identifier];
}

- (void)sessionInitiated:(RMSession *)session
{
    [session setLocalIdentity:self.localIdentity];
    
    if ([_managerDelegate respondsToSelector:@selector(sessionInitiated:)]) {
        [_managerDelegate sessionInitiated:session];
    }
}

#pragma mark - Notifications

- (void)handleApplicationDidEnterBackgroundNotification:(NSNotification *)notification
{
    [self stopBroadcasting];
    [self.activeSession stop];
}

@end

