//
//  NSString+createSHA512.m
//  Romo
//

#import "NSString+createSHA512.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (createSHA512)

+ (NSString *)createSHA512:(NSString *)source
{
    if (source.length) {
        const char *s = [source cStringUsingEncoding:NSASCIIStringEncoding];
        NSData *keyData = [NSData dataWithBytes:s length:strlen(s)];
        uint8_t digest[CC_SHA512_DIGEST_LENGTH] = {0};
        CC_SHA512(keyData.bytes, keyData.length, digest);
        NSData *out = [NSData dataWithBytes:digest length:CC_SHA512_DIGEST_LENGTH];

        return [out description];
    }
    return nil;
}

- (NSString *)sha1
{
    const char *cstr = [self cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:self.length];

    uint8_t digest[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1(data.bytes, data.length, digest);

    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];

    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

@end
