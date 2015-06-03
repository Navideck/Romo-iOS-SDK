//
//  RMSocket.h
//  Romo
//

#import "RMNetworkUtilities.h"

@class RMSocket, RMPacket, RMAddress;

#pragma mark - SocketDelegate --

/**
 * Receives packets and status updates from a Socket instance.
 */
@protocol RMSocketDelegate <NSObject>

@optional
/**
 * Called whenever the Socket receives a Packet.
 * @param socket The Socket which received the Packet.
 * @param packet The received Packet.
 */
- (void)socket:(RMSocket *)socket receivedPacket:(RMPacket *)packet;

/**
 * Called whenever the Socket successfully sends a Packet.
 * @param socket The Socket which sent the Packet.
 * @param packet The sent Packet.
 */
- (void)socket:(RMSocket *)socket didSendPacket:(RMPacket *)packet;

/**
 * Called whenever the Socket fails to send a Packet.
 * @param socket The Socket which failed to send the Packet.
 * @param packet The Packet which wasn't sent.
 */
- (void)socket:(RMSocket *)socket failedSendingPacket:(RMPacket *)packet;

/**
 * Called when the Socket succesfully connected.
 * @param socket The newly connected Socket.
 */
- (void)socketConnected:(RMSocket *)socket;

/**
 * Called when the Socket fails to connect.
 * @param socket The Socket which failed to connect.
 */
- (void)socketConnectionFailed:(RMSocket *)socket;

/**
 * Called when the Socket closes.
 * @param socket The closed Socket.
 */
- (void)socketClosed:(RMSocket *)socket; 

@end

#pragma mark -
#pragma mark - Socket --

/**
 * An Objective-C wrapper around a native Berkely Socket.
 * Used for sending Packets across the network.
 */
@interface RMSocket : NSObject
{
    NativeSocket _nativeSocket;
    SocketType  _socketType;
    
    dispatch_queue_t _readQueue;
    dispatch_queue_t _writeQueue;
    
    dispatch_source_t _readSource;
}

#pragma mark - Properties --

/// The Socket's delegate object.
@property (nonatomic, weak) id<RMSocketDelegate> delegate;

/// The Socket's local Address.
@property (nonatomic, strong) RMAddress *localAddress;

/// The Socket peer's Address, if a peer exists.
@property (nonatomic, strong) RMAddress *peerAddress;

/// Whether or not the Socket is currently connected to a remote host.
@property (nonatomic, readonly) BOOL isConnected;

#pragma mark - Initialization --

/**
 * Initializes a Socket based on the provided type and Address.
 * @warning Do not use externally. Call one of the other initializers which will in turn call this method.
 * @return An initialized Socket instance.
 * @param type The SocketType to create.
 * @param address The Address to use for the Socket.
 */
- (id)initSocketWithType:(SocketType)type withAddress:(RMAddress *)address;

/**
 * Initializes a TCP Socket with the provided native Socket FD, received from accept().
 * @return An initialized TCP Socket instance.
 * @param socketFd The BSD Socket descriptor provided by accept().
 */
- (id)initStreamWithNativeSocket:(NativeSocket)socketFd;

/**
 * Initializes a UDP Socket listening on the provided port.
 * @return An initialized UDP Socket instance.
 * @param port The port to listen on.
 */
- (id)initDatagramListenerWithPort:(NSString *)port;

#pragma mark - Methods --

/**
 * Sends the Packet over the Socket.
 * @param packet The Packet to send.
 */
- (void)sendPacket:(RMPacket *)packet;

/**
 * Attempts to connect the socket to the previously specified host.
 */
- (void)connect;

/**
 * Shuts down the Socket, closing all connections.
 */
- (void)shutdown;

@end
