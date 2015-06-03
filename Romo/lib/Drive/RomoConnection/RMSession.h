//
//  Session.h
//  Romo
//

#import "RMSocket.h"

@class RMPeer, RMService, RMSession;

#pragma mark - Constants --

/// The various states a Session can be in.
typedef enum 
{
    STATE_INITIATED,
    STATE_PENDING,
    STATE_CONNECTED,
    STATE_PAUSED,
    STATE_DISCONNECTED
} SessionState;

#pragma mark -
#pragma mark - SessionDelegate --

/**
 * Receives updates regarding the status of the Session, as well as Services which are received through it.
 */
@protocol RMSessionDelegate <NSObject>
@optional

/**
 * Called whenever a Session has been accepted or rejected by the Peer on the other end.
 * @param session The Session which was accepted.
 * @param accepted Whether or not the Session was accepted.
 */
- (void)session:(RMSession *)session accepted:(BOOL)accepted;

/**
 * Called whenever a Session has began.
 * @param session The Session which has began.
 */
- (void)sessionBegan:(RMSession *)session;

/**
 * Called whenever a Session is paused.
 * @param session The Session which has been paused.
 */
- (void)sessionPaused:(RMSession *)session;

/**
 * Called whenever a Session has resumed.
 * @param session The Session which has resumed.
 */
- (void)sessionResumed:(RMSession *)session;

/**
 * Called whenever a Session is ended.
 * @param session The Session which was ended.
 */
- (void)sessionEnded:(RMSession *)session;

/**
 * Called when a session receives the peer identity of the connected peer.
 * @param session The Session receive the peer identity.
 * @param peer The Peer identity of the device on the other end of the Session.
 */
- (void)session:(RMSession *)session receivedPeerIdentity:(RMPeer *)peer;

/**
 * Called whenever a Session receives a Service.
 * @param session The Session which received the Service.
 * @param service The Service which was received.
 */
- (void)session:(RMSession *)session receivedService:(RMService *)service;

/**
 * Called whenever a Session starts a Service.
 * @param session The Session which started the Service.
 * @param service The Service which was started.
 */
- (void)session:(RMSession *)session startedService:(RMService *)service;

/**
 * Called whenever a Session finishes a Service.
 * @param session The Session which finished the Service.
 * @param service The Service which was finished.
 */
- (void)session:(RMSession *)session finishedService:(RMService *)service;

@end

#pragma mark -
#pragma mark - Session --

/**
 * Represents a specific connection between two Peers. 
 * Used for basic communication of available Services and status.
 * DO NOT add functionality to this class or extend it.
 * Use Services/Subscribers for that functionality.
 */
@interface RMSession : NSObject <RMSocketDelegate>

#pragma mark - Properties --

/// The session's delegate object.
@property (nonatomic, weak) id<RMSessionDelegate> delegate;

/// The current state of the Session.
@property (nonatomic, readonly, assign) SessionState state;

/// The Socket over which communication between Peer's occurs.
@property (nonatomic, readonly, strong) RMSocket *dataSocket;

/// The local Peer identity (our's).
@property (nonatomic, strong) RMPeer *localIdentity;

/// The remote Peer identity (their's).
@property (nonatomic, strong) RMPeer *remotePeer;

# pragma mark -- Creation --

/**
 * Creates an autoreleased Session instance with the provided Socket.
 * Used by the Listener for newly initiated Sessions, as their sockets come from accept().
 * @return An autoreleased Session instance.
 * @param socket A Socket instance created from a SocketServer.
 */
+ (RMSession *)sessionWithSocket:(RMSocket *)socket;

/**
 * Creates an autoreleased Session instance with the provided local and remote peer identities.
 * @return An autoreleased Session instance.
 * @param remotePeer The remote Peer to initiate a Session with.
 * @param localIdentity Our local identity for use during the Session.
 */
+ (RMSession *)sessionWithRemotePeer:(RMPeer *)remotePeer localIdentity:(RMPeer *)localIdentity;

# pragma mark -- Initialization --

/**
 * Initializes a Session instance with the provided Socket.
 * Used by the Listener for newly initiated Sessions, as their sockets come from accept().
 * @return An initialized Session instance.
 * @param socket A Socket instance created from a SocketServer.
 */
- (id)initWithSocket:(RMSocket *)socket;

/**
 * Initializes a Session instance with the provided local and remote peer identities.
 * @return An initialized Session instance.
 * @param remotePeer The remote Peer to initiate a Session with.
 * @param localIdentity Our local identity for use during the Session.
 */
- (id)initWithRemotePeer:(RMPeer *)remotePeer localIdentity:(RMPeer *)localIdentity; 

# pragma mark -- Methods --

/**
 * Requests the peer identity for the initiated session.
 */
- (void)requestIdentity;

/**
 * Starts the initiated Session.
 */
- (void)start;

/**
 * Resumes a paused Session.
 */
- (void)resume;

/**
 * Pauses the Session.
 */
- (void)pause;

/**
 * Stops the initiated Session.
 */
- (void)stop;

/**
 * Add the provided Service to the Session, informing the remote Peer of its availability,
 * then starts the Service.
 * @param service The Service to start.
 */
- (void)startService:(RMService *)service;

/**
 * Stops the provided Service and removes it from the Session.
 * Informs the Peer that it is no longer available.
 * @param service The Service to stop.
 */
- (void)stopService:(RMService *)service;

@end
