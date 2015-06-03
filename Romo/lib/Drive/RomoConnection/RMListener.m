//
//  Listener.m
//  Romo
//

#import "RMListener.h"

#pragma mark - Listener (Private) --

@interface RMListener ()
{
    RMSocketServer *_listenerSocket;
}

- (id)initWithPort:(NSString *)port;

@end

#pragma mark -
#pragma mark - Implementation (Listener) --

@implementation RMListener

#pragma mark - Properties --

@synthesize delegate=_delegate;

#pragma mark - Creation --

+ (RMListener *)listenerWithPort:(NSString *)port;
{
    return [[RMListener alloc] initWithPort:port];
}

#pragma mark - Initialization --

- (id)initWithPort:(NSString *)port
{
    self = [super init];
    if (self) {
        // I have seen a case where making/breaking WiFi connections too
        // fast results in the creation of a new socket failing.  This gives
        // us a few attempts to create the socket, with some delay in between
        // each attempt, in order to slow things down.
        for (int i = 0; i < 3 && _listenerSocket == nil; i++) {
            _listenerSocket = [[RMSocketServer alloc] initWithPort:port];
            
            if (!_listenerSocket) {
                sleep(1);
            }
        }

        _listenerSocket.delegate = self;
    }
    
    return self;
}

- (void)dealloc
{
    [_listenerSocket shutdown];
    _listenerSocket = nil;
}

#pragma mark - SocketServerDelegate --

- (void)socketServer:(RMSocketServer *)server acceptedSocket:(RMSocket *)socket
{
    [_delegate sessionInitiated:[RMSession sessionWithSocket:socket]];
}

@end