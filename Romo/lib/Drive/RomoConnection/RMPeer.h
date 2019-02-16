//
//  Peer.h
//  Romo
//

#import "RMSerializable.h"
#import <Romo/UIDevice+Romo.h>
#import "UIDevice+Temporary.h"

@class RMAddress;

#pragma mark - Peer

/**
 * Represents a device to be used across a Connection.
 */
@interface RMPeer : RMSerializable

#pragma mark - Properties

/// The Peer's Address on the network.
@property (nonatomic, strong) RMAddress *address;

/// The Peer's unique identifier on the network.
@property (nonatomic, copy) NSString *identifier;

/// The Peer's name (for display purposes only).
@property (nonatomic, copy) NSString *name;

/// The Peer's app software version
@property (nonatomic, copy) NSString *appVersion;

/** Device hardware information */

typedef enum {
    UIDeviceColorWhite,
    UIDeviceColorBlack,
    UIDeviceColorSilver,
    UIDeviceColorRed,
    UIDeviceColorPink,
    UIDeviceColorYellow,
    UIDeviceColorBlue,
} UIDeviceColor;

@property (nonatomic) UIDevicePlatform devicePlatform;
@property (nonatomic) UIDeviceColor deviceColor;

#pragma mark - Creation

/**
 * Creates an autoreleased Peer instance with all default properties except its name.
 * @return An autoreleased Peer instance.
 * @param address The network Address of the Peer.
 */
+ (RMPeer *)peerWithAddress:(RMAddress *)address;

/**
 * Creates an autoreleased Peer instance.
 * @return An autoreleased Peer instance.
 * @param address The network Addres of the Peer.
 * @param identifier An NSString containing the unique identifier of the Peer.
 */
+ (RMPeer *)peerWithAddress:(RMAddress *)address identifier:(NSString *)identifier;

/**
 * Creates an autoreleased Peer instance from a Bonjour TXT record dictionary.
 * @return An autoreleased Peer instance.
 * @param address The network Addres of the Peer.
 * @param dictionary A dictionary containing the Bonjour TXT record.
 * @param identifier An NSString containing the unique identifier of the Peer.
 */
+ (RMPeer *)peerWithAddress:(RMAddress *)address dictionary:(NSDictionary *)dictionary identifier:(NSString *)identifier;

#pragma mark - Initialization

/**
 * Initializes a Peer instance with all default properties except its name.
 * @return An initialized Peer instance.
 * @param name An NSString containing the display name of the Peer.
 */
- (id)initWithName:(NSString *)name;

/**
 * Initializes a Peer instance with all default properties except its name.
 * @return An initialized Peer instance.
 * @param address The network Address of the Peer.
 */
- (id)initWithAddress:(RMAddress *)address;

/**
 * Initializes a Peer instance.
 * @return An initialized Peer instance.
 * @param address The network Addres of the Peer.
 * @param identifier An NSString containing the unique identifier of the Peer.
 */
- (id)initWithAddress:(RMAddress *)address identifier:(NSString *)identifier;

/**
 * Initializes a Peer instance from a Bonjour TXT record dictionary.
 * @return An initialized Peer instance.
 * @param address The network Addres of the Peer.
 * @param dictionary A dictionary containing the Bonjour TXT record.
 * @param identifier An NSString containing the unique identifier of the Peer.
 */
- (id)initWithAddress:(RMAddress *)address dictionary:(NSDictionary *)dictionary identifier:(NSString *)identifier;

#pragma mark - Methods--

/**
 * Serializes the Peer into a TXTRecord Dictionary to be used over Bonjour.
 * @return An autoreleased NSDictionary containing the serialized Peer.
 */
- (NSDictionary *)serializeToDictionary;

/**
 * Updates the Peer's properties based on the data contained within the TXTRecord Dictionary.
 * @param dictionary An NSDictionary containing the Bonjour TXTRecord.
 */
- (void)updateWithDictionary:(NSDictionary *)dictionary;

@end
