//
//  NetworkUtils.m
//  Romo
//

#import "RMNetworkUtilities.h"
#import <SystemConfiguration/CaptiveNetwork.h>

#pragma mark - Constants --

#define HEADER_SIZE sizeof(uint32_t)

#pragma mark -
#pragma mark - Implementation (NetworkUtils) --

@implementation RMNetworkUtilities

#pragma mark - Class Methods --

+ (uint32_t)headerSize
{
    return HEADER_SIZE;
}

+ (void)packInteger:(NSUInteger)integer intoBuffer:(uint8_t *)buffer offset:(uint32_t)offset
{    
    buffer[offset++] = (integer >> 24) & 0xFF;
    buffer[offset++] = (integer >> 16) & 0xFF;
    buffer[offset++] = (integer >> 8)  & 0xFF;
    buffer[offset]   = (integer)       & 0xFF;
}

+ (NSString *)WiFiName
{
    NSArray *ifs = (NSArray *)CFBridgingRelease(CNCopySupportedInterfaces());
    id info = nil;
    
    for (NSString *ifnam in ifs) {
        info = (NSDictionary *)CFBridgingRelease(CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam));
        if (info && [info count]){
            break;
        }
    }
    return [info objectForKey:@"SSID"];
}

@end

#pragma mark -
#pragma mark - Implementation (NSData (NetworkUtils)) --

@implementation NSData (NetworkUtils)

#pragma mark - Methods --

- (char *)bytesWithHeader
{
    const NSUInteger size = [self length];
    const void *data = [self bytes];
    
    char *dataWithHeader = malloc(size + HEADER_SIZE);
    
    [RMNetworkUtilities packInteger:size intoBuffer:(uint8_t *)dataWithHeader offset:0];
    memcpy(dataWithHeader + HEADER_SIZE, data, size);
    
    return dataWithHeader;
}

- (NSUInteger)sizeWithHeader
{
    return [self length] + HEADER_SIZE;
}

@end
