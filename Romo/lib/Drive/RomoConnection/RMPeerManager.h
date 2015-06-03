//
//  PeerManager.h
//  Romo
//

#import <Foundation/Foundation.h>
#import "RMBroadcaster.h"

@class RMPeer;

#pragma mark - PeerDelegate --

/**
 * Receives Peer information as they are added, updated, and removed.
 */
@protocol RMPeerDelegate <NSObject>

/**
 * Called whenever a Peer is discovered on the current Connection.
 * @param peer The newly added Peer.
 */
- (void)peerAdded:(RMPeer *)peer;

/**
 * Called whenever a Peer is updated on the current Connection.
 * @param peer The updated Peer.
 */
- (void)peerUpdated:(RMPeer *)peer;

/**
 * Called whenever a Peer disconnects from the current Connection.
 * @param peer The disconnected Peer.
 */
- (void)peerRemoved:(RMPeer *)peer;

@end

#pragma mark -
#pragma mark - PeerDelegate --

/**
 * Manages both the monitoring of external Peers on the Connection
 * and the broadcasting of the local Peer's state.
 */
@interface RMPeerManager : NSObject <RMBroadcasterDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate> {}

#pragma mark - Properties --

/// The PeerDelegate associated with this object.
@property (nonatomic, weak) id<RMPeerDelegate> delegate;

#pragma mark - Creation --

/**
 * Creates an autoreleased PeerManager instance for the provided ConnectionType and port.
 * @return An autoreleased PeerManager instance.
 * @param port An NSString containing the port on which to broadcast the device's status.
 */
+ (RMPeerManager *)managerWithPort:(NSString *)port;

#pragma mark - Methods --

/**
 * Generates and returns an autoreleased, immutable copy of the Peer list's NSDictionary.
 * @return An autorleased, immutable copy of the manager's Peer list.
 */
- (NSDictionary *)peerList;

/**
 * Begins broadcasting the provided Peer identity on the Connection.
 * @param identity The Peer identity to broadcast.
 */
- (void)startBroadcastWithIdentity:(RMPeer *)identity;

/**
 * Updates the currently broadcasted Peer identity.
 * @param identity The updated Peer identity to broadcast.
 */
- (void)updateIdentity:(RMPeer *)identity;

/**
 * Shuts down the broadcast of availability on the Connection, informing others that it is not currently available.
 */
- (void)shutdownBroadcast;

/**
 * Restarts broadcasting of availability on the Connection with the last used Peer identity.
 */
- (void)restartBroadcast;
/**
 * Start Listening for Romo Services
 */
- (void)startListening;

@end
