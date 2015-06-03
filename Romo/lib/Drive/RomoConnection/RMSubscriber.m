//
//  Subscriber.m
//  Romo
//

#import "RMSubscriber.h"
#import "RMSocket.h"

#pragma mark - Implementation (Subscriber) --

@implementation RMSubscriber

#pragma mark - Creation --

+ (RMSubscriber *)subscriberWithService:(RMService *)service
{
    return [[RMSubscriber alloc] initWithService:service];
}

#pragma mark - Initialization --

- (id)initWithService:(RMService *)service
{
    if (self = [super init])
    {
        _name = [[service name] copy];
        _serviceAddress = [service address];
        _protocol = [service protocol];
    }
    
    return self;
}

- (void)dealloc
{
    [self stop];
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

@end
