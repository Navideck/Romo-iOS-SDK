//
//  UIDevice+UDID.m
//  Romo
//

#import "UIDevice+UDID.h"
#import "NSString+createSHA512.h"

@implementation UIDevice (UDID)

+ (NSString *)UDID
{
    return [[[UIDevice currentDevice] identifierForVendor].UUIDString sha1];
}

@end
