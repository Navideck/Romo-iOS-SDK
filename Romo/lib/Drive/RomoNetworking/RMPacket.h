//
//  RMPacket.h
//  Romo
//

#import "RMSerializable.h"
#import "RMAddress.h"
#import "RMMessage.h"

#pragma mark - Packet

/**
 * A class for sending Messages over the network.
 */
@interface RMPacket : NSObject

#pragma mark - Properties

/// The source Address of the Packet. Set on receipt.
@property (nonatomic, strong) RMAddress *source;

/// The destination Address of the Packet. Must be set before sending over UDP.
@property (nonatomic, strong) RMAddress *destination;

/// The Message to wrap the Packet around.
@property (nonatomic, strong) RMMessage *message;

#pragma mark - Creation

/**
 * Creates an autoreleased Packet with the provided Message. 
 * Can be sent over TCP.
 * @return An autoreleased Packet instance.
 * @param message The message to wrap the Packet around.
 */
+ (RMPacket *)packetWithMessage:(RMMessage *)message;

/**
 * Creates an autoreleased Packet with the provided Message and destination Address. 
 * Can be sent over UDP.
 * @return An autoreleased Packet instance.
 * @param message The message to wrap the Packet around.
 * @param destination The Address to send the Packet to.
 */
+ (RMPacket *)packetWithMessage:(RMMessage *)message destination:(RMAddress *)destination;

/**
 * Creates an autoreleased Packet with a Message deserialized from the provided data. 
 * Received from TCP.
 * @return An autoreleased Packet instance.
 * @param data The data to deserialize a Message from.
 */
+ (RMPacket *)packetWithData:(NSData *)data;

/**
 * Creates an autoreleased Packet with a Message deserialized from the provided data and source Address.
 * Received from UDP.
 * @return An autoreleased Packet instance.
 * @param data The data to deserialize a Message from.
 * @param source The Address the Packet was received from.
 */
+ (RMPacket *)packetWithData:(NSData *)data source:(RMAddress *)source;

#pragma mark - Initialization

/**
 * Initializes a Packet with the provided Message. 
 * Can be sent over TCP.
 * @return An initialized Packet instance.
 * @param message The message to wrap the Packet around.
 */
- (id)initWithMessage:(RMMessage *)message;

/**
 * Initializes a Packet with the provided Message and destination Address. 
 * Can be sent over UDP.
 * @return An initialized Packet instance.
 * @param message The message to wrap the Packet around.
 * @param destination The Address to send the Packet to.
 */
- (id)initWithMessage:(RMMessage *)message destination:(RMAddress *)destination;

/**
 * Initializes a Packet with a Message deserialized from the provided data. 
 * Received from TCP.
 * @return An initialized Packet instance.
 * @param data The data to deserialize a Message from.
 */
- (id)initWithData:(NSData *)data;

/**
 * Initializes a Packet with a Message deserialized from the provided data and source Address.
 * Received from UDP.
 * @return An initialized Packet instance.
 * @param data The data to deserialize a Message from.
 * @param source The Address the Packet was received from.
 */
- (id)initWithData:(NSData *)data source:(RMAddress *)source;

#pragma mark - Methods

/**
 * Returns the Packet's Message in serialized form.
 * @return An NSData containing the serialized Message from the Packet.
 */
- (NSData *)serialize;

@end