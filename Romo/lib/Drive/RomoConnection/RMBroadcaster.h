//
//  RMBroadcaster.h
//  Romo
//

#import <Foundation/Foundation.h>
#pragma mark - Constants --

#define ROMO_DOMAIN @"local."
#define ROMO_TYPE @"_romo._tcp"

@class RMPeer;

#pragma mark -
#pragma mark - BroadcasterDelegate --

/**
 * Receives messages from the Broadcaster upon success or failure.
 */
@protocol RMBroadcasterDelegate <NSObject>

/**
 * Called on broadcast success.
 */
- (void)broadcastSucceeded;

/**
 * Called on broadcast failure.
 */
- (void)broadcastFailed;

@end

#pragma mark -
#pragma mark - Broadcaster --

/**
 * Broadcasts the device's availability across a network.
 */
@interface RMBroadcaster : NSObject <NSNetServiceDelegate> {}

#pragma mark - Properties --

/// The Broadcaster's delegate object.
@property (nonatomic, weak) id<RMBroadcasterDelegate> delegate;

#pragma mark - Creation --

/**
 * Creates an autoreleased Broadcaster object with the provided type and port.
 * @return An autoreleased Broadcaster object.
 * @param port An NSString object containing the port number to broadcast as available.
 */
+ (RMBroadcaster *)broadcasterWithPort:(NSString *)port;

#pragma mark - Methods --

/**
 * Starts broadcasting the provided Peer identity's availability.
 * @param identity The device's identity to be broadcasted.
 */
- (void)startWithIdentity:(RMPeer *)identity;

/**
 * Updates the Peer identity currently being broadcast.
 * @param identity The new Peer identity to be broadcast.
 */ 
- (void)updateIdentity:(RMPeer *)identity;

/**
 * Starts or restarts broadcasting the availability of the current Peer identity without changing the identity.
 */
- (void)broadcastAvailability;

/**
 * Shuts down the current broadcast, informing the network that the device is no longer available.
 */
- (void)shutdownBroadcast;

@end
