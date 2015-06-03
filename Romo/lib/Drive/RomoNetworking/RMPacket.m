//
//  RMPacket.m
//  Romo
//

#import "RMPacket.h"

#pragma mark - Constants

#define KEY_MESSAGE @"key_message"
#define KEY_DATA @"key_data"

#pragma mark -
#pragma mark - Implementation (Packet)

@implementation RMPacket

#pragma mark - Properties

@synthesize source=_source, destination=_destination;
@synthesize message=_message;

#pragma mark - Creation

+ (RMPacket *)packetWithMessage:(RMMessage *)message
{
    return [[RMPacket alloc] initWithMessage:message];
}

+ (RMPacket *)packetWithMessage:(RMMessage *)message destination:(RMAddress *)destination
{
    return [[RMPacket alloc] initWithMessage:message destination:destination];
}

+ (RMPacket *)packetWithData:(NSData *)data
{
    return [[RMPacket alloc] initWithData:data];
}

+ (RMPacket *)packetWithData:(NSData *)data source:(RMAddress *)source
{
    return [[RMPacket alloc] initWithData:data source:source];
}

#pragma mark - Initialization

- (id)initWithMessage:(RMMessage *)message
{
    if (self = [super init])
    {
        [self setMessage:message];
    }
    
    return self;
}

- (id)initWithMessage:(RMMessage *)message destination:(RMAddress *)destination
{
    if (self = [super init])
    {
        [self setMessage:message];
        [self setDestination:destination];
    }
    
    return self;
}

- (id)initWithData:(NSData *)data
{
    if (self = [super init])
    {
        [self setMessage:(RMMessage *) [RMMessage deserializeData:data]];
    }
    
    return self;
}

- (id)initWithData:(NSData *)data source:(RMAddress *)source
{
    if (self = [self initWithData:data])
    {
        [self setSource:source];
    }
    
    return self;
}

#pragma mark - Dealloc

#pragma mark - Methods

- (NSData *)serialize
{
    return [_message serialize];
}

@end