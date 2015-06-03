//
//  Message.m
//  Romo
//

#import "RMMessage.h"

#pragma mark - Constants --

#define KEY_CONTENT @"key_content"
#define KEY_PACKAGE @"key_package"

#pragma mark -
#pragma mark - Implementation (Message) --

@implementation RMMessage

#pragma mark - Properties --

@synthesize content=_content, package=_package;

#pragma mark - Creation --

+ (RMMessage *)messageWithContent:(NSInteger)content
{
    return [[RMMessage alloc] initWithContent:content];
}

+ (RMMessage *)messageWithContent:(NSInteger)content string:(NSString *)string
{
    return [[RMMessage alloc] initWithContent:content string:string];
}

+ (RMMessage *)messageWithContent:(NSInteger)content data:(NSData *)data
{
    return [[RMMessage alloc] initWithContent:content data:data];    
}

+ (RMMessage *)messageWithContent:(NSInteger)content package:(id<Serializable>)package
{
    return [[RMMessage alloc] initWithContent:content package:package];
}

#pragma mark - Initialization --

- (id)initWithContent:(NSInteger)content
{
    if (self = [super init])
    {
        [self setContent:content];
    }
    
    return self;
}

- (id)initWithContent:(NSInteger)content string:(NSString *)string
{
    if (self = [super init])
    {
        [self setContent:content];
        [self setPackage:[string dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    return self;
}

- (id)initWithContent:(NSInteger)content data:(NSData *)data
{
    if (self = [super init])
    {
        [self setContent:content];
        [self setPackage:data];
    }
    
    return self;
}

- (id)initWithContent:(NSInteger)content package:(id<Serializable>)package
{
    if (self = [super init])
    {
        [self setContent:content];
        [self setPackage:[package serialize]];
    }
    
    return self;
}

#pragma mark - Serializable --

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super init])
    {
        [self setContent:[coder decodeIntegerForKey:KEY_CONTENT]];
        [self setPackage:[coder decodeObjectForKey:KEY_PACKAGE]];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_content forKey:KEY_CONTENT];
    [coder encodeObject:_package forKey:KEY_PACKAGE];
}

@end
