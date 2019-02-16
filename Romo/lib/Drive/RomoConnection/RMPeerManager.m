//
//  PeerManager.m
//  Romo
//

#import "RMPeerManager.h"
#import <arpa/inet.h>
#import <Romo/UIDevice+UDID.h>
#import "RMAddress.h"
#import "RMBroadcaster.h"
#import "RMPeer.h"

#pragma mark - Constants --

#define RESOLVE_TIMEOUT 5

#pragma mark -
#pragma mark - PeerManager (Private) --

@interface RMPeerManager ()
{
    NSMutableDictionary *_peerList;
    
    RMBroadcaster *_broadcaster;
    NSNetService *_service;
    NSNetServiceBrowser *_browser;
    NSMutableArray *_services;
    
    NSString *_serviceName;
}

- (id)initWithPort:(NSString *)port;

@end

#pragma mark -
#pragma mark - RemotePeerManager (Private) --

@interface RemotePeerManager : RMPeerManager

- (id)initWithPort:(NSString *)port;

@end

#pragma mark -
#pragma mark - Implementation (PeerManager) --

@implementation RMPeerManager

#pragma mark - Properties --

@synthesize delegate=_delegate;

#pragma mark - Creation --

+ (RMPeerManager *)managerWithPort:(NSString *)port
{
    return [[RMPeerManager alloc] initWithPort:port];
}

#pragma mark - Initialization --

- (id)initWithPort:(NSString *)port
{
    if (self = [super init])
    {
        _peerList = [[NSMutableDictionary alloc] init];
        _serviceName = [UIDevice currentDevice].UDID;
        
        _browser = [[NSNetServiceBrowser alloc] init];
        [_browser setDelegate:self];
        
        _services = [[NSMutableArray alloc] init];
        
        _broadcaster = [RMBroadcaster broadcasterWithPort:port];
    }
    
    return self;
}

- (void)dealloc
{
    _services = nil;
    _peerList = nil;
    
    [_service stop];
    _service = nil;
    
    [_broadcaster shutdownBroadcast];
    _broadcaster = nil;
    
    [_browser stop];
    _browser = nil;
}

#pragma mark - Methods --

- (NSDictionary *)peerList
{
    return [NSDictionary dictionaryWithDictionary:_peerList];
}

- (void)startBroadcastWithIdentity:(RMPeer *)identity
{
    [_broadcaster startWithIdentity:identity];
}

- (void)updateIdentity:(RMPeer *)identity
{
    [_broadcaster updateIdentity:identity];
}

- (void)shutdownBroadcast
{
    [_broadcaster shutdownBroadcast];
}

- (void)restartBroadcast
{
    [_broadcaster broadcastAvailability];
}

- (void)broadcastSucceeded
{
    
}

- (void)broadcastFailed
{
    
}

- (void)startListening
{
    [_browser searchForServicesOfType:ROMO_TYPE inDomain:ROMO_DOMAIN];
}

#pragma mark - NSNetServiceDelegate --

- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    NSArray *addresses = [service addresses];
    
    for (NSData *data in addresses)
    {
        struct sockaddr *socketAddress;
        
        socketAddress = (struct sockaddr *) [data bytes];
        
        if (socketAddress->sa_family == AF_INET)
        {            
            struct sockaddr_in *addr_in = (struct sockaddr_in *) socketAddress;
            addr_in->sin_port = htons(addr_in->sin_port);
            
            RMAddress *address = [RMAddress addressWithSockAddress:socketAddress];
            
            RMPeer *peer = nil;
            NSData *data = [service TXTRecordData];
            
            if (data)
                peer = [RMPeer peerWithAddress:address dictionary:[NSNetService dictionaryFromTXTRecordData:data] identifier:[service name]];
            else
                peer = [RMPeer peerWithAddress:address identifier:[service name]];
            
            _peerList[[peer identifier]] = peer;
            [_delegate peerAdded:peer];
        }
    }
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
    NSLog(@"RNTPeerManager Error resolving address: %@", errorDict[NSNetServicesErrorCode]);
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
    RMPeer *peer = _peerList[[sender name]];
    [peer updateWithDictionary:[NSNetService dictionaryFromTXTRecordData:data]];
    
    [_delegate peerUpdated:peer];
}

#pragma mark - NSNetServiceBrowserDelegate --

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)more
{
    if (![_services containsObject:service]
        && ![_serviceName isEqualToString:[service name]])
    {
        [_services insertObject:service atIndex:[_services count]];
        [service setDelegate:self];
        [service resolveWithTimeout:RESOLVE_TIMEOUT];        
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)more
{
    if ([_services containsObject:service])
        [_services removeObject:service];
    
    [_delegate peerRemoved:_peerList[[service name]]];
    
    if ([[_peerList allKeys] containsObject:[service name]])
        [_peerList removeObjectForKey:[service name]];
}

@end
