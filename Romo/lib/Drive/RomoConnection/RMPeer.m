
//
//  RMPeer.m
//  Romo
//

#import "RMPeer.h"
#import <Romo/UIDevice+UDID.h>
#import "RMAddress.h"

#pragma mark - Constants

#define KEY_NAME @"key_name"
#define KEY_IDENTIFIER @"key_identifier"
#define KEY_APPVERSION @"key_appversion"
#define KEY_DEVICEPLATFORM @"key_devicePlatform"
#define KEY_DEVICECOLOR @"key_deviceColor"

@implementation RMPeer

#pragma mark - Creation

+ (RMPeer *)peerWithAddress:(RMAddress *)address
{
    return [[RMPeer alloc] initWithAddress:address];
}

+ (RMPeer *)peerWithAddress:(RMAddress *)address identifier:(NSString *)identifier
{
    return [[RMPeer alloc] initWithAddress:address identifier:identifier];
}

+ (RMPeer *)peerWithAddress:(RMAddress *)address dictionary:(NSDictionary *)dictionary identifier:(NSString *)identifier
{
    return [[RMPeer alloc] initWithAddress:address dictionary:dictionary identifier:identifier];
}

#pragma mark - Initialization

- (id)init
{
    return [self initWithName:@"Romo"];
}

- (id)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        _name = name.length ? name : @"Romo";
        _identifier = [UIDevice currentDevice].UDID;
    }
    return self;
}

- (id)initWithAddress:(RMAddress *)address
{
    return [self initWithAddress:address name:@"Romo"];
}

- (id)initWithAddress:(RMAddress *)address identifier:(NSString *)identifier
{
    if (self = [self initWithAddress:address name:@"Romo"]) {
        [self setIdentifier:identifier];
    }
    
    return self;
}

- (id)initWithAddress:(RMAddress *)address dictionary:(NSDictionary *)dictionary identifier:(NSString *)identifier
{
    if (self = [self initWithAddress:address])
    {        
        [self updateWithDictionary:dictionary];
        [self setIdentifier:identifier];
    }
    
    return self;
}

- (id)initWithAddress:(RMAddress *)address name:(NSString *)name
{
    if (self = [super init])
    {
        [self setAddress:address];
        [self setName:name];
    }
    
    return self;
}

#pragma mark - Equality

- (BOOL)isEqual:(id)object
{
    // Equality is determined by the peer's identifier
    return [object isKindOfClass:[self class]] && [[object identifier] isEqualToString:self.identifier];
}

#pragma mark - Private Methods

- (NSDictionary *)serializeToDictionary
{
    UIDevicePlatform platform = self.devicePlatform;
    NSData *platformData = [NSData dataWithBytes:&platform length:sizeof(platform)];

    UIDeviceColor color = self.deviceColor;
    NSData *colorData = [NSData dataWithBytes:&color length:sizeof(color)];

    return @{
             @"name" : [self.name dataUsingEncoding:NSUTF8StringEncoding],
             @"identifier": [self.identifier dataUsingEncoding:NSUTF8StringEncoding],
             @"appversion" : [self.appVersion dataUsingEncoding:NSUTF8StringEncoding],
             @"devicePlatform" : platformData,
             @"deviceColor" : colorData,
             };
}

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
    if (dictionary[@"name"]) {
        self.name = [[NSString alloc] initWithData:dictionary[@"name"] encoding:NSUTF8StringEncoding];
    }

    if (dictionary[@"identifier"]) {
        self.identifier = [[NSString alloc] initWithData:dictionary[@"identifier"] encoding:NSUTF8StringEncoding];
    }

    if (dictionary[@"appversion"]) {
        self.appVersion = [[NSString alloc] initWithData:dictionary[@"appversion"] encoding:NSUTF8StringEncoding];
    }

    if (dictionary[@"devicePlatform"]) {
        UIDevicePlatform platform;
        [dictionary[@"devicePlatform"] getBytes:&platform length:sizeof(platform)];
        self.devicePlatform = platform;
    }

    if (dictionary[@"deviceColor"]) {
        UIDeviceColor color;
        [dictionary[@"deviceColor"] getBytes:&color length:sizeof(color)];
        self.deviceColor = color;
    }
}

#pragma mark - Serializable

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super init])
    {
        self.name = [coder decodeObjectForKey:KEY_NAME];
        self.identifier = [coder decodeObjectForKey:KEY_IDENTIFIER];
        self.appVersion = [coder decodeObjectForKey:KEY_APPVERSION];
        self.devicePlatform = [[coder decodeObjectForKey:KEY_DEVICEPLATFORM] intValue];
        self.deviceColor = [[coder decodeObjectForKey:KEY_DEVICECOLOR] intValue];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:KEY_NAME];
    [coder encodeObject:_identifier forKey:KEY_IDENTIFIER];
    [coder encodeObject:_appVersion forKey:KEY_APPVERSION];
    [coder encodeObject:@(self.devicePlatform) forKey:KEY_DEVICEPLATFORM];
    [coder encodeObject:@(self.deviceColor) forKey:KEY_DEVICECOLOR];
}

@end
