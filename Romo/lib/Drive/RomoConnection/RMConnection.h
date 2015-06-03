//
//  Connection.h
//  Romo
//

#import <Foundation/Foundation.h>
#import "RMPeerManager.h"
#import "RMListener.h"

@class RMPeer, RMSession;

#pragma mark - ConnectionDelegate --

/**
 * Receives available Peer and Session objects from the Connection.
 */
@protocol RMConnectionDelegate <NSObject>

/**
 * Called whenever a Peer is found.
 * @param peer The newly found Peer.
 */
- (void)peerAdded:(RMPeer *)peer;

/**
 * Called whenever a Peer has been updated.
 * @param peer The updated Peer.
 */
- (void)peerUpdated:(RMPeer *)peer;

/**
 * Called whenever a Peer is no longer available.
 * @param peer The Peer which has been removed.
 */
- (void)peerRemoved:(RMPeer *)peer;

/**
 * Called whenever a Session is initiated over this Connection.
 * @param session The newly initiated Session.
 */
- (void)sessionInitiated:(RMSession *)session;

@end

#pragma mark -
#pragma mark - Connection --

/**
 * Represents a Device's connection to the network (local or remote).
 * Used to communicate with other device's regarding availability,
 * and to initiate new Session instances.
 */
@interface RMConnection : NSObject <RMPeerDelegate, RMListenerDelegate>
{
    RMPeerManager *_peerManager;
    RMListener *_listener;
    RMSession *_activeSession;
}

#pragma mark - Properties --

/// The Connection's delegate object.
@property (nonatomic, weak) id<RMConnectionDelegate> delegate;

/// Describes the current status of the Connection.
@property (nonatomic, readonly) BOOL isConnected;

#pragma mark - Creation --

/**
 * Creates an autoreleased Connection object with the specified type.
 * @return An autorleased Connection object.
 */
+ (RMConnection *)connection;

#pragma mark - Methods --

/**
 * Start's broadcasting the device's availability with the provided identity.
 * @param identity The Peer identity to begin broadcasting.
 */
- (void)startBroadcastWithIdentity:(RMPeer *)identity;

/**
 * Update's the device's status on the Connection.
 * @param identity The update Peer identity to broadcast. 
 */
- (void)updateIdentity:(RMPeer *)identity;

/**
 * Shuts down broadcast of the device's availability, 
 * notifying others that it is no longer available.
 */
- (void)shutdownBroadcast;

/**
 * Starts listening for Romo services
 */
- (void)startListening;

/**
 * Restarts broadcast of the device's availability with the last used Peer identity.
 */
- (void)restartBroadcast;

/**
 * Sets the Connection's active session to the one provided, 
 * and updates the device's availabiltiy accordingly.
 * @param session The Session that was started.
 */
- (void)sessionStarted:(RMSession *)session;

/**
 * Removes the session as the Connection's active session,
 * and updates the device's availabiltiy accordingly.
 * @param session The session that has ended.
 */
- (void)sessionStopped:(RMSession *)session;

@end
