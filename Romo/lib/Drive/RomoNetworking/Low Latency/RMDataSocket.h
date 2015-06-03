//
//  DataSocket.h
//  Romo
//

#import "RMNetworkUtilities.h"

@class RMDataSocket, RMDataPacket, RMAddress;

#pragma mark - DataSocketDelegate --

/**
 * Receives packets and status updates from a DataSocket instance.
 */
@protocol RMDataSocketDelegate <NSObject>

@optional
/**
 * Called whenever the DataSocket receives a Packet.
 * @param DataSocket The DataSocket which received the Packet.
 * @param packet The received Packet.
 */
- (void)dataSocket:(RMDataSocket *)dataSocket receivedDataPacket:(RMDataPacket *)packet;

/**
 * Called when the DataSocket succesfully connected.
 * @param DataSocket The newly connected DataSocket.
 */
- (void)dataSocketConnected:(RMDataSocket *)dataSocket;

/**
 * Called when the DataSocket fails to connect.
 * @param DataSocket The DataSocket which failed to connect.
 */
- (void)dataSocketConnectionFailed:(RMDataSocket *)dataSocket;

/**
 * Called when the DataSocket closes.
 * @param DataSocket The closed DataSocket.
 */
- (void)dataSocketClosed:(RMDataSocket *)dataSocket;

@end

#pragma mark -
#pragma mark - DataSocket --

/**
 * An Objective-C wrapper around a native Berkely DataSocket.
 * Used for sending Packets across the network.
 */
@interface RMDataSocket : NSObject
{
    NativeSocket _nativeSocket;
    SocketType  _socketType;
    
    dispatch_queue_t _readQueue;
    dispatch_queue_t _writeQueue;
    
    dispatch_source_t _readSource;
}

#pragma mark - Properties --

/// The DataSocket's delegate object.
@property (nonatomic, weak) id<RMDataSocketDelegate> delegate;

/// The DataSocket's local Address.
@property (nonatomic, strong) RMAddress *localAddress;

/// The DataSocket peer's Address, if a peer exists.
@property (nonatomic, strong) RMAddress *peerAddress;

/// Whether or not the DataSocket is currently connected to a remote host.
@property (nonatomic, readonly) BOOL isConnected;

#pragma mark - Initialization --

/**
 * Initializes a DataSocket based on the provided type and Address.
 * @warning Do not use externally. Call one of the other initializers which will in turn call this method.
 * @return An initialized DataSocket instance.
 * @param type The SocketType to create.
 * @param address The Address to use for the DataSocket.
 */
- (id)initDataSocketWithType:(SocketType)type withAddress:(RMAddress *)address;

/**
 * Initializes a UDP DataSocket listening on the provided port.
 * @return An initialized UDP DataSocket instance.
 * @param port The port to listen on.
 */
- (id)initDatagramListenerWithPort:(NSString *)port;

#pragma mark - Methods --

/**
 * Sends the Packet over the DataSocket.
 * @param packet The Packet to send.
 */
- (void)sendDataPacket:(RMDataPacket *)dataPacket;

/**
 * Attempts to connect the DataSocket to the previously specified host.
 */
- (void)connect;

/**
 * Shuts down the DataSocket, closing all connections.
 */
- (void)shutdown;

@end
