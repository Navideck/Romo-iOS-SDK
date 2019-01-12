//
//  Service.m
//  Romo
//

#import "RMService.h"
#import "RMAddress.h"

#pragma mark - Constants --

#define KEY_NAME        @"key_name"
#define KEY_PORT        @"key_port"
#define KEY_PROTOCOL    @"key_protocol"

#pragma mark -
#pragma mark - Implementation (Service) --

@implementation RMService

#pragma mark - Creation --

+ (RMService *)serviceWithName:(NSString *)name
{
    return [[RMService alloc] initWithName:name];
}

+ (RMService *)serviceWithName:(NSString *)name port:(NSString *)port protocol:(ServiceProtocol)protocol
{
    return [[RMService alloc] initWithName:name port:port protocol:protocol];
}

#pragma mark - Initialization --

- (id)initWithName:(NSString *)name
{
    return [self initWithName:name port:@"" protocol:PROTOCOL_UNKNOWN];
}

- (id)initWithName:(NSString *)name port:(NSString *)port protocol:(ServiceProtocol)protocol;
{
    if (self = [super init])
    {
        [self setName:name];
        [self setPort:port];
        [self setProtocol:protocol];
    }
    
    return self;
}

#pragma mark - Methods --

- (void)start
{
    [self doesNotRecognizeSelector:_cmd];
}

- (void)stop
{
    [self doesNotRecognizeSelector:_cmd];    
}

- (RMSubscriber *)subscribe
{
    return nil;
}

#pragma mark - Serializable --

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super init])
    {
        [self setName:[coder decodeObjectForKey:KEY_NAME]];
        [self setPort:[coder decodeObjectForKey:KEY_PORT]];
        [self setProtocol:(ServiceProtocol)[coder decodeIntegerForKey:KEY_PROTOCOL]];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:KEY_NAME];
    [coder encodeObject:_port forKey:KEY_PORT];
    [coder encodeInteger:_protocol forKey:KEY_PROTOCOL];
}

@end
