//
//  Listener.h
//  Romo
//

#import <Foundation/Foundation.h>
#import "RMSocketServer.h"
#import "RMSession.h"

#pragma mark - ListenerDelegate --

/**
 * Receives initiated Sessions from the Listener.
 */
@protocol RMListenerDelegate <NSObject>

/**
 * Called whenever a new Session is initiated.
 * @param session The newly initiated Session.
 */
- (void)sessionInitiated:(RMSession *)session;

@end

#pragma mark -
#pragma mark - Listener --
/**
 * Listens for incoming Sessions on a Connection.
 */
@interface RMListener : NSObject <RMServerDelegate>

#pragma mark - Properties --

/// The ListenerDelegate associated with this object.
@property (nonatomic, weak) id<RMListenerDelegate> delegate;

#pragma mark - Methods --

/**
 * Creates an autoreleased Listener object with the provided ConnectionType and port.
 * @return An autoreleased Listener object.
 * @param port An NSString object containing the port on which to listen.
 */
+ (RMListener *)listenerWithPort:(NSString *)port;

@end
