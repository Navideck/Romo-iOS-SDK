//
//  SocketServer.m
//  Romo
//

#import "RMSocketServer.h"
#import "RMAddress.h"

#pragma mark - Constants --

#define BACKLOG 10

@interface RMSocketServer ()

- (void)setupAcceptSource;
- (void)doAccept;

@end

@implementation RMSocketServer

@synthesize delegate = _delegate;

- (id)initWithPort:(NSString *)port
{
    RMAddress *address = [RMAddress localAddressWithPort:port];
    self = [super initSocketWithType:SOCK_STREAM withAddress:address];
    if (self) {
        [self setupAcceptSource];
        
        AddressInfo *info = [address infoWithType:SOCK_STREAM];
        
        int yes = 1;
        
        if (setsockopt(_nativeSocket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1)  {
            perror("RMSocketServer:  setsockopt() failed");
            return nil;
        } 
        
        struct sockaddr_in *addr = (struct sockaddr_in *) info->ai_addr;
        addr->sin_addr.s_addr = htonl(INADDR_ANY);
        
        if (bind(_nativeSocket, info->ai_addr, info->ai_addrlen) == -1) {
            perror("RMSocketServer: bind() failed");
            return nil;
        }
        
        struct linger lin = {1,0};
        setsockopt(_nativeSocket, SOL_SOCKET, SO_LINGER, &lin, sizeof(struct linger));
        
        if (listen(_nativeSocket, BACKLOG) == -1) {
            perror("RMSocketServer: listen() failed:");
            return nil;
        }
    }
    
    return self;
}

#pragma mark - Private Methods --

- (void)setupAcceptSource
{
    _readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _nativeSocket, 0, _readQueue);

    __weak RMSocketServer *weakSelf = self;
	dispatch_source_set_event_handler(_readSource, ^{
        @autoreleasepool {
            [weakSelf doAccept];
        }
    });
    
    dispatch_source_set_cancel_handler(_readSource, ^{ @autoreleasepool {
        close(self->_nativeSocket);
    }});
    
    dispatch_resume(_readSource);
}

- (void)doAccept
{
    struct sockaddr_in addr;
    socklen_t addrLen = sizeof(addr);
    
    NativeSocket nativeSocket = accept(_nativeSocket, (struct sockaddr *)&addr, &addrLen);
    
    if (nativeSocket == -1) {
        NSLog(@"RMSocketServer: accept() failed");
    }
    
    RMSocket *newSocket = [[RMSocket alloc] initStreamWithNativeSocket:nativeSocket];
    
    [newSocket setPeerAddress:[RMAddress addressWithSockAddress:(SockAddress *) &addr]];
    
    [_delegate socketServer:self acceptedSocket:newSocket];
}

@end
