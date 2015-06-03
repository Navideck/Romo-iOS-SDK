//
//  Service.h
//  Romo
//

#import "RMNetworkUtilities.h"
#import "RMSerializable.h"
#import "RMAddress.h"

@class RMSubscriber;

#pragma mark - Constants --

/// The types of Protocols available to a Service.
typedef enum
{
    PROTOCOL_UNKNOWN = -1,
    PROTOCOL_TCP = IPPROTO_TCP,
    PROTOCOL_UDP = IPPROTO_UDP
} ServiceProtocol;

#pragma mark -
#pragma mark - Service --

/**
 * Represents a Service available for use by other Peers across a Connection.
 * Non-connection related data should always be sent over a Service, not a Session.
 * Override this class to create new Services for use across the Network.
 * Make sure you do all of the following:
 * - Create a Subscriber which pairs with this Service (and is returned by -[Service subscribe]).
 * - Define the ServiceProtocol used by the new Service.
 * - Add modules as necessary to provide your Service with the desired functionality.
 * - Properly describe the interaction between your Service and your Subscriber.
 */
@interface RMService : RMSerializable

#pragma mark - Properties --

/// The name of the Service. Should be unique.
@property (nonatomic, copy) NSString *name;

/// The port on which the Service is accessible. Should be unique.
@property (nonatomic, strong) NSString *port;

/// The ServiceProtocol by which the Service communicates at its port.
@property (nonatomic, assign) ServiceProtocol protocol;

/// The network Address of the Service. Set upon receipt from a Session, do not set manually.
@property (nonatomic, strong) RMAddress *address;

#pragma mark - Initialization --

/**
 * Initializes a Service with the provided name.
 * @return An initialized Service instance.
 * @param name The name of the Service.
 */
- (id)initWithName:(NSString *)name;

/**
 * Initializes a Service with the provided name, port, and protocol.
 * @return An initialized Service instance.
 * @param name The name of the Service.
 * @param port The port at which the Service can be reached.
 * @param protocol The protocl by which the Service communicates.
 */
- (id)initWithName:(NSString *)name port:(NSString *)port protocol:(ServiceProtocol)protocol;

#pragma mark - Methods --

/**
 * Starts the Service.
 * Must be overriden with start logic.
 */
- (void)start;

/**
 * Stops the Service.
 * Must be overriden with stop logic.
 */
- (void)stop;

/**
 * Creates and returns an autoreleased instance of the Service's paired Subscriber.
 * MUST be overriden by classes extending Service.
 * @return An autoreleased instance of the Service's paired Subscriber.
 */
- (RMSubscriber *)subscribe;

@end
