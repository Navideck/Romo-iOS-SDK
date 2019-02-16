//
//  RMCharacterImage.m
//  RMCharacter
//

#import "RMCharacterImage.h"

#include <sys/socket.h> // Per msqr
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#import <UIDevice-Hardware/UIDevice-Hardware.h>

@implementation RMCharacterImage

static NSMutableDictionary *_cache;
static int _currentCapacity;
static const int _maxCapacity = 3500000;

+ (void)emptyCache {
    _cache = nil;
    _currentCapacity = 0;
}

+ (RMCharacterImage *)imageNamed:(NSString*)name {
    if (!name.length) {
        return nil;
    }
    
    if (!_cache) {
        _cache = [NSMutableDictionary dictionaryWithCapacity:20];
    }
    
    if ([_cache objectForKey:name]) {
        return (RMCharacterImage *)[_cache objectForKey:name];
    }
    
    NSArray *comps = [name componentsSeparatedByString:@"."];
    NSString* extension;
    if (comps.count < 2) {
        extension = @"png";
    } else {
        extension = comps[1];
    }
    
    NSBundle* bundle = [NSBundle bundleForClass:self.classForCoder];
    NSString *mainBundlePath = [[[bundle resourceURL] URLByAppendingPathComponent:@"RMCharacter.bundle"] path];

    NSString *filePath = nil;
    if (![comps[0] hasSuffix:@"@1x"]) {
        filePath = [[NSBundle bundleWithPath:mainBundlePath] pathForResource:[NSString stringWithFormat:@"%@@2x", comps[0]] ofType:extension];
    } else {
        filePath = [[NSBundle bundleWithPath:mainBundlePath] pathForResource:comps[0] ofType:extension];
    }

    RMCharacterImage *image = (RMCharacterImage *)[RMCharacterImage imageWithContentsOfFile:filePath];
    if (image) {
        _currentCapacity += image.size.width * image.size.height;
        if (_currentCapacity > _maxCapacity) {
            [self emptyCache];
        }
        
        [_cache setObject:image forKey:[name lastPathComponent]];
    }
    
    return image;
}

#pragma mark - (Non)-Retina Fetching

+ (UIImage *)nonRetinaImageNamed:(NSString *)name
{
    NSString *resource = name;
    NSString *type = [name pathExtension];
    if (type.length) {
        resource = [name substringToIndex:name.length - 1 - type.length];
    }
    resource = [resource stringByAppendingString:@"@1x"];
    name = [resource stringByAppendingPathExtension:type];

    return [self imageNamed:name];
}

+ (UIImage *)smartImageNamed:(NSString *)name
{
    BOOL retina = [self usesRetinaGraphics];
    UIImage *result = nil;
            
    if (!retina) {
        result = [self nonRetinaImageNamed:name];
    }
    
    if (!result) {
        result = [self imageNamed:name];
    }
    
    return result;
}

#pragma mark - Private Methods

+ (BOOL)usesRetinaGraphics
{
    static BOOL flag = YES;
    static BOOL usesRetina = NO;
    
    if (flag) {
        flag = NO;
        BOOL isRetinaiPad = (([self deviceFamily] == UIDeviceFamilyiPad) && ([UIScreen mainScreen].scale == 2.0f));
        BOOL isTelepresencePhoneOrPod = [self isFastDevice];
        usesRetina = isRetinaiPad || isTelepresencePhoneOrPod;
    }
    return usesRetina;
}

+ (BOOL)isFastDevice
{
    static BOOL flag = YES;
    static BOOL isDockableTelepresenceDevice = NO;
    
    if (flag) {
        flag = NO;
        
        BOOL isiPod = [self deviceFamily] == UIDeviceFamilyiPod;
        BOOL isiPhone = [self deviceFamily] == UIDeviceFamilyiPhone;
        isDockableTelepresenceDevice = (isiPod || isiPhone) && ![self isShortiPod] && ![self isiPhoneThreeOrOlder];
    }
    return isDockableTelepresenceDevice;
}

+ (BOOL)isShortiPod
{
    static BOOL flag = YES;
    static BOOL isShortiPod = NO;
    
    if (flag) {
        flag = NO;
        
        BOOL isiPod = [self deviceFamily] == UIDeviceFamilyiPod;
        BOOL isShort = [[UIScreen mainScreen] bounds].size.height < 500;
        isShortiPod = isiPod && isShort;
    }
    return isShortiPod;
}

+ (BOOL)isiPhoneThreeOrOlder
{
    static BOOL flag = YES;
    static BOOL isiPhoneThreeOrOlder = NO;
    
    if (flag) {
        flag = NO;
        
        BOOL isIphone = [self deviceFamily] == UIDeviceFamilyiPhone;
        NSPredicate *iphoneTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"iPhone[0-3].*"];
        BOOL isThreeOrOld = [iphoneTest evaluateWithObject:[self getSysInfoByName:"hw.machine"]];
        isiPhoneThreeOrOlder = isIphone && isThreeOrOld;
    }
    return isiPhoneThreeOrOlder;
}

+ (UIDeviceFamily)deviceFamily
{
    NSString *platform = [self getSysInfoByName:"hw.machine"];
    if ([platform hasPrefix:@"iPhone"]) return UIDeviceFamilyiPhone;
    if ([platform hasPrefix:@"iPod"]) return UIDeviceFamilyiPod;
    if ([platform hasPrefix:@"iPad"]) return UIDeviceFamilyiPad;
    if ([platform hasPrefix:@"AppleTV"]) return UIDeviceFamilyAppleTV;
    
    return UIDeviceFamilyUnknown;
}

+ (NSUInteger)getSysInfo:(uint)typeSpecifier
{
    size_t size = sizeof(int);
    int results;
    int mib[2] = {CTL_HW, typeSpecifier};
    sysctl(mib, 2, &results, &size, NULL, 0);
    return (NSUInteger) results;
}

+ (NSString *)getSysInfoByName:(char *)typeSpecifier
{
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
    
    free(answer);
    return results;
}

@end
