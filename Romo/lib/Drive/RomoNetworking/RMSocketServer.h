//
//  SocketServer.h
//  Romo
//

#import "RMSocket.h"

@class RMSocketServer;

#pragma mark - SocketServerDelegate --

/**
 * Receives accepted Sockets from the SocketServer.
 */
@protocol RMServerDelegate <RMSocketDelegate>

/**
 * Called whenever the SocketServer receives a Socket.
 * @param server The SocketServer which accepted the Socket.
 * @param socket The Socket which was accepted.
 */
- (void)socketServer:(RMSocketServer *)server acceptedSocket:(RMSocket *)socket;

@end

#pragma mark - SocketServer --

/**
 * A TCP Socket instance that listens on a port, and accepts all incoming connections.
 * These accepted Sockets are passed out to the Server's delegate.
 */
@interface RMSocketServer : RMSocket

#pragma mark - Properties --

/// The SocketServer's delegate object.
@property (nonatomic, weak) id<RMServerDelegate> delegate;

#pragma mark - Initialization --

/**
 * Initializes a SocketServer instance to listen on the provided port.
 * @return An initialized SocketServer instance.
 * @param port The port to listen for incoming connections on.
 */
- (id)initWithPort:(NSString *)port;

@end
