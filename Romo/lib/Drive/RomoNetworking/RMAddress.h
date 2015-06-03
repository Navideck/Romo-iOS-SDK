//
//  RMAddress.h
//  Romo
//

#import "RMNetworkUtilities.h"
#import "RMSerializable.h"

#pragma mark - Address

/**
 * Represents an Address on a network.
 * Contains methods for getting the device's MAC Address,
 * as well as converting between NSStrings and native SockAddress types.
 */
@interface RMAddress : RMSerializable

#pragma mark - Properties

/// An NSString representation of the Address's host component (IP address).
@property (nonatomic, copy) NSString *host;

/// An NSString representation of the Address's port.
@property (nonatomic, copy) NSString *port;

#pragma mark - Creation

/**
 * Creates an autoreleased Address with the Localhost (127.0.0.1) IP, and the provided port.
 * @return An autoreleased Address object.
 * @param port The port to use for the Address.
 */
+ (RMAddress *)localAddressWithPort:(NSString *)port;

/**
 * Creates an autoreleased Address with the provided host and port.
 * @return An autoreleased Address object.
 * @param host The hostname to use for the Address.
 * @param port The port to use for the Address.
 */
+ (RMAddress *)addressWithHost:(NSString *)host port:(NSString *)port;

/**
 * Creates an autoreleased Address using a native SockAddress struct.
 * @return An autoreleased Address object.
 * @param address The SockAddress struct to create this Address from.
 */
+ (RMAddress *)addressWithSockAddress:(SockAddress *)address;

#pragma mark - Initialization

/**
 * Initializes an Address with the Localhost (127.0.0.1) IP, and the provided port.
 * @return An initialized Address object.
 * @param port The port to use for the Address.
 */
- (id)initLocalhostWithPort:(NSString *)port;

/**
 * Initializes an Address with the provided host and port.
 * @return An initialized Address object.
 * @param host The hostname to use for the Address.
 * @param port The port to use for the Address.
 */
- (id)initWithHost:(NSString *)host port:(NSString *)port;

/**
 * Initializes an Address using a native SockAddress struct.
 * @return An initialized Address object.
 * @param address The SockAddress struct to create this Address from.
 */
- (id)initWithSockAddress:(SockAddress *)address;

#pragma mark - Methods

/**
 * Creates an AddressInfo struct based on the SocketType provided.
 * @return A native AddressInfo struct for the Address.
 * @param type The SocketType to look up the info for.
 */
- (AddressInfo *)infoWithType:(SocketType)type;

/**
 * Gets the Address's AddressFamily.
 * @return The Address's AddressFamily (IPv4/IPv6).
 */
- (AddressFamily)family;

/**
 * Creates a native SockAddress struct from the Address.
 * @return A native SockAddress struct.
 */
- (SockAddress *)sockAddress;

@end
