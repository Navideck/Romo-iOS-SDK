//
//  NetworkingManager.h
//  Romo
//

#import "RMConnection.h"
#import "RMPeer.h"
#import "RMSession.h"

#pragma mark - SessionManagerDelegate --

/**
 * Receives updates related to the Session.
 */
@protocol RMSessionManagerDelegate <NSObject>

/**
 * Called whenever the Session's peerList has been updated.
 * @param peerList The updated list of Peers.
 */
- (void)peerListUpdated:(NSArray *)peerList;

/**
 * Called whenever a Session has been initiated.
 * @param session The newly initiated Session.
 */
- (void)sessionInitiated:(RMSession *)session;

@end

#pragma mark -
#pragma mark - SessionManager --

/**
 * A Singleton object through which the Application can interact with other devices on the Network.
 * Responsible for starting and stopping connections, broadcasting the device's availability over them,
 * searching for other devices, listening for new Sessions, and initiating them with others.
 */
@interface RMSessionManager : NSObject <RMConnectionDelegate>

#pragma mark - Properties --

/// The currently active Session. Not retained, as we don't want ownership of the object.
@property (nonatomic, weak) RMSession *activeSession;

/// If we have a paused Session, this retains a strong handle to it:
@property (nonatomic, strong) RMSession *pausedSession;

/// The SessionManagerDelegate associated with this object.
@property (nonatomic, weak) id<RMSessionManagerDelegate> managerDelegate;
@property (nonatomic, weak) id<RMConnectionDelegate> connectionDelegate;

/// The device's identity. Used for broadcasting our availability over a Connection.
@property (nonatomic, strong) RMPeer *localIdentity;

@property (nonatomic, readonly, strong) NSArray *peerList;

#pragma mark - Singleton Access --

/**
 * Accesses the Singleton SessionManager object if it exists, and Creates it if it doesn't.
 * @return The Singleton SessionManager object.
 */
+ (RMSessionManager *)shared;

#pragma mark - Methods --

/**
 * Starts a connection and starts listening.
 */
- (void)startListeningForRomos;

/**
 * Stops the connection.
 */
- (void)stopListeningForRomos;

/**
 * Starts broadcasting the device's availability on any currently running connections,
 * using the provided Peer identity.
 * @param identity The local Peer identity to broadcast.
 */
- (void)startBroadcastWithIdentity:(RMPeer *)identity;

/**
 * Updates the identity of the Peer being broadcast.
 * @param peer The update Peer identity.
 */
- (void)updateIdentity:(RMPeer *)peer;

/**
 * Shuts down broadcast on all currently running connections.
 * Informs others that the device is not currently available.
 */
- (void)stopBroadcasting;

/**
 * Attempts to initiate a new Session with the provided Peer.
 * @return The newly initiated Session.
 * @param peer The Peer with which to initiate the Session.
 */
- (RMSession *)initiateSessionWithPeer:(RMPeer *)peer;

@end
