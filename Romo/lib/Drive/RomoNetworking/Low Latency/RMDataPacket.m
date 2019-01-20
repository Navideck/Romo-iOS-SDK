//
//  DataPacket.m
//  Romo
//

#import "RMDataPacket.h"

#define HEADER_SIZE 8

#pragma mark - Implementation (DataPacket) --

@implementation RMDataPacket

#pragma mark - Creation --

+ (RMDataPacket *)dataPacketFromBytes:(const void *)bytes
{
    return [[RMDataPacket alloc] initWithBytes:bytes];
}

+ (RMDataPacket *)dataPacketWithType:(DataPacketType)type
{
    return [[RMDataPacket alloc] initWithType:type];
}

+ (RMDataPacket *)dataPacketWithType:(DataPacketType)type data:(const void *)data dataSize:(uint32_t)dataSize
{
    return [[RMDataPacket alloc] initWithType:type data:data dataSize:dataSize];
}

+ (RMDataPacket *)dataPacketWithType:(DataPacketType)type data:(const void *)data dataSize:(uint32_t)dataSize destination:(RMAddress *)destination
{
    return [[RMDataPacket alloc] initWithType:type data:data dataSize:dataSize destination:destination];
}

#pragma mark - Initialization --

- (id)initWithBytes:(const void *)bytes
{
    uint32_t *intPtr = (uint32_t *) bytes;
    return [self initWithType:intPtr[0] data:bytes + [RMDataPacket headerSize] dataSize:intPtr[1]];
}

- (id)init
{
    return [self initWithType:0];
}

- (id)initWithType:(DataPacketType)type
{
    return [self initWithType:type data:NULL dataSize:0];
}

- (id)initWithType:(DataPacketType)type data:(const void *)data dataSize:(uint32_t)dataSize
{
    return [self initWithType:type data:data dataSize:dataSize destination:nil];
}

- (id)initWithType:(DataPacketType)type data:(const void *)data dataSize:(uint32_t)dataSize destination:(RMAddress *)destination
{
    if (self = [super init]) {
        _type = type;
        _dataSize = dataSize;
        
        if (_dataSize > 0 && data != NULL) {
            _data = malloc(_dataSize);
            memcpy(_data, data, _dataSize);
        }
            
        _destination = destination;
    }
    
    return self;
}

#pragma mark - Dealloc --

- (void)dealloc
{
    if (_data) {
        free(_data);
    }
}

#pragma mark - Methods --

+ (uint32_t)headerSize
{
    return HEADER_SIZE;
}

- (void)serializeToBytes:(char [])bytes
{
    int32_t *intPtr = (int32_t *) bytes;
    
    intPtr[0] = _type;
    intPtr[1] = _dataSize;
    
    memcpy(bytes + [RMDataPacket headerSize], _data, _dataSize);
}

- (uint32_t)packetSize
{
    return [RMDataPacket headerSize] + _dataSize;
}

- (void *)extractData
{
    void *data = _data;
    _data = NULL;
    
    return data;
}

@end
