//
//  Subscriber.h
//  Romo
//

#import "RMService.h"

#pragma mark - Subscriber --

/**
 * Returned from its paired Service's subscribe method,
 * this class should be extended to provide specific functionality
 * for interacting with its pair Service.
 * Make sure you do all of the following:
 * - Create a Service which pairs with this Subscriber.
 * - Properly describe the interaction between your Service and your Subscriber.
 */
@interface RMSubscriber : NSObject

#pragma mark - Properties --

/// The name of the Service this Subscriber came from.
@property (nonatomic, copy, readonly) NSString *name;

/// The network Address at which the paired Service can be reached.
@property (nonatomic, strong, readonly) RMAddress *serviceAddress;

/// The ServiceProtocol used to communicate with the paired Service.
@property (nonatomic, assign, readonly) ServiceProtocol protocol;

#pragma mark - Creation --

/**
 * Creates an autorleased Subscriber instance paired with the provided Service.
 * @return An autoreleased Subscriber instance.
 * @param service The Service to subscribe to.
 */
+ (RMSubscriber *)subscriberWithService:(RMService *)service;

#pragma mark - Initialization --

/**
 * Initializes an autorleased Subscriber instance paired with the provided Service.
 * @return An initialized Subscriber instance.
 * @param service The Service to subscribe to.
 */
- (id)initWithService:(RMService *)service;

#pragma mark - Methods --

/**
 * Starts the Subscriber.
 * Must be overriden with start logic.
 */
- (void)start;

/**
 * Stops the Subscriber.
 * Must be overriden with stop logic.
 */
- (void)stop;

@end
