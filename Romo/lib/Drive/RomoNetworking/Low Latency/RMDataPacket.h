//
//  DataPacket.h
//  Romo
//

#import "RMSerializable.h"
#import "RMAddress.h"
#import "RMMessage.h"

typedef enum
{
    DATA_TYPE_OTHER = 0,
    DATA_TYPE_AUDIO,
    DATA_TYPE_VIDEO,
    DATA_MESSAGE_ON,
    DATA_MESSAGE_OFF
} DataPacketType;

#pragma mark - DataPacket --

/**
 * A class for sending Messages over the network.
 */
@interface RMDataPacket : NSObject

#pragma mark - Properties --

/// The content to send with the packet:
@property (nonatomic) DataPacketType type;

/// The data to send with the packet:
@property (nonatomic) void *data;

/// The data to send with the packet:
@property (nonatomic) uint32_t dataSize;
@property (nonatomic, readonly) uint32_t packetSize;

@property (nonatomic, strong) RMAddress *source;
/// The destination Address of the DataPacket. Must be set before sending over UDP.
@property (nonatomic, strong) RMAddress *destination;

#pragma mark - Creation --

+ (RMDataPacket *)dataPacketFromBytes:(const void *)bytes;

+ (RMDataPacket *)dataPacketWithType:(DataPacketType)type;

/**
 * Creates an autoreleased DataPacket with a Message deserialized from the provided data.
 * Received from TCP.
 * @return An autoreleased DataPacket instance.
 * @param data The data to deserialize a Message from.
 */
+ (RMDataPacket *)dataPacketWithType:(DataPacketType)type data:(const void *)data dataSize:(uint32_t)dataSize;

/**
 * Creates an autoreleased DataPacket with a Message deserialized from the provided data and source Address.
 * Received from UDP.
 * @return An autoreleased DataPacket instance.
 * @param data The data to deserialize a Message from.
 * @param source The Address the DataDataPacket was received from.
 */
+ (RMDataPacket *)dataPacketWithType:(DataPacketType)type data:(const void *)data dataSize:(uint32_t)dataSize destination:(RMAddress *)destination;

#pragma mark - Initialization --

- (id)initWithBytes:(const void *)bytes;

- (id)initWithType:(DataPacketType)type;

/**
 * Initializes a DataPacket with a Message deserialized from the provided data.
 * Received from TCP.
 * @return An initialized DataPacket instance.
 * @param data The data to deserialize a Message from.
 */
- (id)initWithType:(DataPacketType)type data:(const void *)data dataSize:(uint32_t)dataSize;

/**
 * Initializes a DataPacket with a Message deserialized from the provided data and source Address.
 * Received from UDP.
 * @return An initialized DataPacket instance.
 * @param data The data to deserialize a Message from.
 * @param source The Address the DataPacket was received from.
 */
- (id)initWithType:(DataPacketType)type data:(const void *)data dataSize:(uint32_t)dataSize destination:(RMAddress *)destination;

+ (uint32_t)headerSize;

- (uint32_t)packetSize;
- (void)serializeToBytes:(char[])bytes;

- (void *)extractData;

@end
